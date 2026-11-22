"""Full-model GRU/FastGRNN training under finetune_output_fc conditions.

User-authorized change: train all DPD parameters, not just the output head.
The default is exactly three epochs; no scheduler, clipping or early stopping.
The body is floating point and the head keeps the original fake quantization.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import os
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch import nn

from finetune_output_fc import ROOT, OPENDPD, PACKAGE, quantize
from fastgrnn_model import FastGRNNDPD


def protect_zero(iq):
    zero=(iq==0).all(-1)
    return iq+torch.stack((zero.to(iq.dtype)*1e-9,torch.zeros_like(iq[...,0])),-1)


class HeadQATModel(nn.Module):
    def __init__(self,core,fast):
        super().__init__()
        self.core=core
        if fast:
            self.head=core.fc_out
            core.fc_out=nn.Identity()
        else:
            self.head=core.backbone.fc_out
            core.backbone.fc_out=nn.Identity()

    def forward(self,iq):
        # Same head arithmetic and STE as retraining/finetune_output_fc.py.
        hidden=quantize(self.core(protect_zero(iq)),15,3)
        products=quantize(hidden.unsqueeze(-2)*quantize(self.head.weight,14,4),21,6)
        acc=torch.zeros_like(products[...,0])
        for product in products.unbind(-1):
            acc=quantize(acc+product,21,6)
        return quantize(acc+quantize(self.head.bias,15,3),15,3)


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--epochs',type=int,default=3)
    ap.add_argument('--fast-only',action='store_true',help='Train only FastGRNN; retain the existing v4.6 comparison')
    a=ap.parse_args()
    if a.epochs<1 or a.out.exists():
        ap.error('Use a new output directory and positive epoch count')
    out=a.out.resolve();out.mkdir(parents=True)
    torch.set_num_threads(2);torch.manual_seed(4574)
    os.chdir(OPENDPD)
    sys.path.insert(0,str(PACKAGE/'tools'));sys.path.insert(0,str(OPENDPD))
    from eval_pa import models,load_dataset,set_target_gain,metrics
    pa_path,=(OPENDPD/'save/DPA_200MHz/train_pa').glob('*.pt')
    dpd_path,=(OPENDPD/'save/DPA_200MHz/train_dpd').glob('*.pt')
    base=models.CoreModel(2,5,3,'rgruwfex',residual_type=2)
    base.load_state_dict(torch.load(dpd_path,map_location='cpu',weights_only=True))
    pa=models.CoreModel(2,8,1,'dgru')
    pa.load_state_dict(torch.load(pa_path,map_location='cpu',weights_only=True))
    pa.eval().requires_grad_(False)
    pa_hash_before={k:v.detach().clone() for k,v in pa.state_dict().items()}
    x,y,v,_,t,_=load_dataset('DPA_200MHz')
    gain=float(set_target_gain(x,y))
    spec=json.loads((OPENDPD/'datasets/DPA_200MHz/spec.json').read_text())
    seg=2560
    assert spec['nperseg']==seg
    train,val,test=[torch.tensor(iq,dtype=torch.float32).reshape(-1,seg,2) for iq in (x,v,t)]
    torch.manual_seed(4574)
    fast=FastGRNNDPD()
    # Reuse only architecture-compatible external parameters. No GRU gates
    # are converted into the new FastGRNN recurrent weights.
    fast.W_in.load_state_dict(base.backbone.W_in.state_dict())
    fast.fc_out.load_state_dict(base.backbone.fc_out.state_dict())
    with torch.no_grad():
        fast.prelu.copy_(base.backbone.in_act.alpha.reshape(()))
        fast.gate_logits.copy_(torch.cat([g.reshape(1) for g in base.backbone.rnn.gates]))
    common=dict(bw_main_ch=spec['bw_main_ch'],n_sub_ch=spec['n_sub_ch'],nperseg=seg)
    config=dict(reference_script=str(ROOT/'retraining/finetune_output_fc.py'),
                epochs=a.epochs,seed=4574,threads=2,device='CPU',optimizer='Adam',lr=0.00025,
                batch_size_segments=1,segment_samples=seg,train_segments=len(train),
                val_segments=len(val),test_segments=len(test),gain=gain,
                loss='mean((frozen_PA(DPD(x))-gain*x)^2) / mean((gain*x)^2)',
                trainable='all DPD parameters',scheduler=None,gradient_clipping=None,
                selection='minimum validation NMSE, including epoch 0',
                pa_frozen=True,body_arithmetic='float32',
                head_arithmetic='hidden Q3.12, weight Q4.10, accum Q6.15, output Q3.12; AP_RND/AP_SAT STE',
                initialization=dict(v46='provided pretrained checkpoint',
                    fastgrnn='51 compatible pretrained external parameters; 186 new recurrent parameters',
                    identical_pretraining=False),
                source_sha256={str(p.relative_to(ROOT)):sha(p) for p in [
                    Path(__file__).resolve(),ROOT/'retraining/fastgrnn_model.py',
                    ROOT/'retraining/finetune_output_fc.py',dpd_path,pa_path,
                    OPENDPD/'datasets/DPA_200MHz/spec.json']},
                dataset_sha256={p.name:sha(p) for p in (OPENDPD/'datasets/DPA_200MHz').glob('*.csv')})
    (out/'config.json').write_text(json.dumps(config,indent=2),encoding='utf-8')
    os.chdir(out)  # OpenDPD EVM writes freq.csv; keep it in this experiment.

    def loss(model,data):
        target=data*gain
        pred=pa(protect_zero(model(data)))
        return (pred-target).square().mean()/target.square().mean()

    @torch.no_grad()
    def evaluate(model,data,save=None):
        dpd_output=model(data)
        pred=pa(protect_zero(dpd_output)).numpy();target=(data*gain).numpy()
        assert np.isfinite(pred).all()
        left,right=metrics.ACLR(pred,fs=spec['input_signal_fs'],**common)
        row=dict(nmse_db=float(metrics.NMSE(pred,target)),
                 evm_db=float(metrics.EVM(pred,target,sample_rate=spec['input_signal_fs'],**common)),
                 acpr_l_dbc=float(left),acpr_r_dbc=float(right))
        if save:
            np.savetxt(save,dpd_output.numpy().reshape(-1,2),fmt='%.12g')
        return row

    rows={};started=time.monotonic()
    model_list=[('fastgrnn',fast,True)] if a.fast_only else [('fastgrnn',fast,True),('v46',base,False)]
    for label,core,is_fast in model_list:
        directory=out/label;directory.mkdir()
        model=HeadQATModel(core,is_fast).train().requires_grad_(True)
        initial={k:v.detach().clone() for k,v in model.state_dict().items()}
        count=sum(p.numel() for p in model.parameters())
        assert count==(237 if is_fast else 591)
        optimizer=torch.optim.Adam(model.parameters(),lr=0.00025)
        # Reset after model construction so both models see identical order.
        torch.manual_seed(4574)
        orders=[torch.randperm(len(train)).tolist() for _ in range(a.epochs)]
        model.eval()
        before=evaluate(model,test,directory/'before_test_out.txt')
        with torch.no_grad(): best=float(10*torch.log10(loss(model,val)))
        selected=0;saved=copy.deepcopy(model.state_dict());history=[]
        torch.save(saved,directory/'initial_checkpoint.pt')
        print(json.dumps(dict(model=label,parameters=count,before=before,val_initial_nmse_db=best)),flush=True)
        for epoch,order in enumerate(orders,1):
            tick=time.monotonic();model.train();losses=[]
            for frame in order:
                optimizer.zero_grad()
                value=loss(model,train[frame:frame+1])
                if not torch.isfinite(value): raise ValueError('Nonfinite training loss')
                value.backward();optimizer.step();losses.append(float(value.detach()))
            model.eval()
            with torch.no_grad(): score=float(10*torch.log10(loss(model,val)))
            if not np.isfinite(score): raise ValueError('Nonfinite validation score')
            if score<best:
                best,selected=score,epoch;saved=copy.deepcopy(model.state_dict())
            record=dict(epoch=epoch,val_nmse_db=score,selected_epoch=selected,
                        train_normalized_mse=float(np.mean(losses)),epoch_seconds=time.monotonic()-tick)
            history.append(record)
            torch.save(model.state_dict(),directory/'last_checkpoint.pt')
            torch.save({'epoch':epoch,'model':model.state_dict(),'optimizer':optimizer.state_dict(),
                        'best_epoch':selected,'best_score':best,'best_model':saved},directory/'training_state.pt')
            (directory/'history.json').write_text(json.dumps(history,indent=2),encoding='utf-8')
            print(json.dumps(dict(model=label,**record)),flush=True)
        model.load_state_dict(saved);model.eval()
        torch.save(saved,directory/'best_checkpoint.pt')
        after=evaluate(model,test,directory/'selected_test_out.txt')
        changed=[name for name,p in saved.items() if not torch.equal(initial[name],p)]
        restored=copy.deepcopy(model.core)
        if is_fast:
            restored.fc_out=copy.deepcopy(model.head)
            params=restored.hardware_parameters()
            (directory/'parameters_float.json').write_text(json.dumps(params,indent=2),encoding='utf-8')
            # Hardware export clips/rounds to exactly the current HLS contract.
            spec_module=importlib.util.spec_from_file_location('fast_pack',ROOT/'v4.6_fastgrnn_outpipe/scripts/pack_parameters.py')
            packer=importlib.util.module_from_spec(spec_module);spec_module.loader.exec_module(packer)
            hardware={}
            for name,shape,bits,integer,unit in packer.GROUPS:
                values=torch.tensor(params[name])
                hardware[name]=quantize(values,bits,integer).tolist()
            (directory/'parameters_hardware.json').write_text(json.dumps(hardware,indent=2),encoding='utf-8')
            (directory/'parameters.txt').write_text(packer.pack(hardware),encoding='utf-8')
        else:
            restored.backbone.fc_out=copy.deepcopy(model.head)
            # Reuse the established 42-file GRU parameter export contract.
            spec_module=importlib.util.spec_from_file_location('existing_train',ROOT/'dpd_training/train.py')
            exporter=importlib.util.module_from_spec(spec_module);spec_module.loader.exec_module(exporter)
            manifest=exporter.export_weights(restored.state_dict(),directory/'weights')
            (directory/'weights/manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
        torch.save(restored.state_dict(),directory/'dpd_float_master.pt')
        row=dict(parameters=count,completed_epochs=a.epochs,selected_epoch=selected,
                 selected_val_nmse_db=best,before_test=before,selected_test=after,
                 selected_changed_tensors=changed,train_orders=orders,history=history)
        rows[label]=row
        (directory/'results.json').write_text(json.dumps(row,indent=2),encoding='utf-8')
        print(json.dumps(dict(model=label,selected_epoch=selected,test=after)),flush=True)
    if a.fast_only:
        previous=ROOT/'retraining/runs/v46_fastgrnn_full_3ep_02/comparison.json'
        rows['v46']=json.loads(previous.read_text(encoding='utf-8'))['models']['v46']
        assert rows['v46']['train_orders']==rows['fastgrnn']['train_orders'][:3]
    else:
        assert rows['v46']['train_orders']==rows['fastgrnn']['train_orders']
    assert all(torch.equal(v,pa.state_dict()[k]) for k,v in pa_hash_before.items())
    result=dict(config=config,models=rows,identical_train_order=True,pa_unchanged=True,
                elapsed_seconds=time.monotonic()-started,
                delta_fastgrnn_minus_v46={k:rows['fastgrnn']['selected_test'][k]-rows['v46']['selected_test'][k]
                                          for k in rows['v46']['selected_test']},
                note=('FastGRNN trained for the requested epochs; v4.6 is the previous 3-epoch run.' if a.fast_only else 'Both models use the same epoch count.')+' Float body + quantized head; not full HLS simulation. Initialization differs.')
    (out/'comparison.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print('DONE',json.dumps(result['delta_fastgrnn_minus_v46']),flush=True)


if __name__=='__main__':
    main()
