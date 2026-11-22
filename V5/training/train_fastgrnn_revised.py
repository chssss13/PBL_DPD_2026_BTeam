"""Train FastGRNN with teacher initialization, then retraining's PA loss.

Teacher pretraining is an extra initialization stage; PA fine tuning retains
Adam lr 0.00025, batch one 2560-sample segment, output head QAT, and the
frozen PA / normalized MSE from finetune_output_fc.py. No change to HLS RTL.
"""
import argparse,copy,hashlib,importlib.util,json,os,sys,time
from pathlib import Path
import numpy as np
import torch
from fastgrnn_model import FastGRNNDPD
from finetune_output_fc import ROOT,OPENDPD,PACKAGE,quantize
from compare_full_models import HeadQATModel,protect_zero

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--teacher-epochs',type=int,default=30)
    ap.add_argument('--pa-epochs',type=int,default=20)
    ap.add_argument('--pa-range-max',type=float,default=1.0)
    ap.add_argument('--teacher-checkpoint',type=Path,help='Reuse a completed teacher stage; retain identical PA order')
    ap.add_argument('--continue-teacher',action='store_true',help='Train from saved teacher weights to --teacher-epochs; Adam is restarted')
    a=ap.parse_args();out=a.out.resolve()
    if a.teacher_checkpoint is not None:a.teacher_checkpoint=a.teacher_checkpoint.resolve()
    if out.exists() or a.teacher_epochs<1 or a.pa_epochs<1:ap.error('Use new output and positive epochs')
    out.mkdir(parents=True);folder=out/'fastgrnn';folder.mkdir()
    torch.set_num_threads(2);torch.manual_seed(4574);os.chdir(OPENDPD)
    sys.path.insert(0,str(PACKAGE/'tools'));sys.path.insert(0,str(OPENDPD))
    from eval_pa import models,load_dataset,set_target_gain,metrics
    dpdpath,=(OPENDPD/'save/DPA_200MHz/train_dpd').glob('*.pt')
    papath,=(OPENDPD/'save/DPA_200MHz/train_pa').glob('*.pt')
    teacher=models.CoreModel(2,5,3,'rgruwfex',residual_type=2)
    teacher.load_state_dict(torch.load(dpdpath,map_location='cpu',weights_only=True));teacher.eval().requires_grad_(False)
    pa=models.CoreModel(2,8,1,'dgru');pa.load_state_dict(torch.load(papath,map_location='cpu',weights_only=True));pa.eval().requires_grad_(False)
    x,y,v,_,test,_=load_dataset('DPA_200MHz');gain=float(set_target_gain(x,y));seg=2560
    tr,va,te=[torch.tensor(a,dtype=torch.float32).reshape(-1,seg,2) for a in (x,v,test)]
    spec=json.loads((OPENDPD/'datasets/DPA_200MHz/spec.json').read_text());assert spec['nperseg']==seg
    with torch.no_grad():
        teacher_train=teacher(tr);teacher_val=teacher(va);teacher_test=teacher(te)
    assert all(torch.isfinite(t).all() for t in (teacher_train,teacher_val,teacher_test))
    torch.manual_seed(4574);student=FastGRNNDPD()
    # Reuse compatible representation but make recurrent states initially
    # near zero, avoiding huge random activations before teacher fitting.
    student.W_in.load_state_dict(teacher.backbone.W_in.state_dict())
    student.fc_out.load_state_dict(teacher.backbone.fc_out.state_dict())
    with torch.no_grad():
        student.prelu.copy_(teacher.backbone.in_act.alpha.reshape(()))
        student.gate_logits.copy_(torch.cat([g.reshape(1) for g in teacher.backbone.rnn.gates]))
        student.zeta_logits.fill_(-4.6);student.nu_logits.fill_(-4.6)
    model=HeadQATModel(student,True).train().requires_grad_(True)
    assert sum(p.numel() for p in model.parameters())==237
    # Output reconstruction and PA loss use same segments/batch/head QAT.
    def teacher_loss(a,b):return (model(a)-b).square().mean()/b.square().mean()
    def pa_loss(a):
        target=a*gain
        output=model(a)
        # Fail before using the PA surrogate outside the observed training
        # amplitude range, including every optimizer minibatch.
        if float(torch.linalg.vector_norm(output.detach(),dim=-1).max())>args_pa_limit:
            raise RuntimeError('PA input exceeded measured training amplitude; stop without extrapolation')
        return (pa(protect_zero(output))-target).square().mean()/target.square().mean()
    @torch.no_grad()
    def audit(data):
        output=model(data);amp=torch.linalg.vector_norm(output,dim=-1)
        return dict(max_amplitude=float(amp.max()),rms_amplitude=float(amp.square().mean().sqrt()),
                    percent_over_train_max=float((amp>a.pa_range_max).float().mean()*100))
    config=dict(seed=4574,optimizer='Adam',lr=0.00025,batch_segments=1,segment_samples=2560,
                train_segments=len(tr),val_segments=len(va),test_segments=len(te),gain=gain,
                teacher_epochs=a.teacher_epochs,pa_epochs=a.pa_epochs,teacher_pretraining_added=True,
                teacher_loss='normalized DPD output MSE to frozen pretrained v4.6',
                pa_loss='normalized MSE frozen PA(DPD(x)) against gain*x',
                pa_range_selection_max=a.pa_range_max,
                selection='PA validation NMSE among checkpoints with all train and validation output amplitudes <= PA training max; otherwise do not mark as eligible',
                teacher_checkpoint_sha256=sha(dpdpath),pa_checkpoint_sha256=sha(papath),
                dataset_sha256={p.name:sha(p) for p in (OPENDPD/'datasets/DPA_200MHz').glob('*.csv')},
                output_head='Q3.12 hidden, Q4.10 weights, Q6.15 accumulation, Q3.12 output, STE',
                body='float32 FastGRNN',pa_frozen=True)
    # Derive operating boundary from training PA input; do not inspect test.
    measured_max=float(np.linalg.norm(x,axis=1).max());assert abs(measured_max-a.pa_range_max)<1e-6
    args_pa_limit=a.pa_range_max
    (out/'config.json').write_text(json.dumps(config,indent=2),encoding='utf-8')
    os.chdir(out);started=time.monotonic();history=[]
    torch.manual_seed(4574);orders=[torch.randperm(len(tr)).tolist() for _ in range(a.teacher_epochs+a.pa_epochs)]
    best=float('inf');beststate=None;bestepoch=0
    opt=torch.optim.Adam(model.parameters(),lr=0.00025)
    if a.teacher_checkpoint is not None:
        source=a.teacher_checkpoint
        original=json.loads((source.parent.parent/'results.json').read_text(encoding='utf-8'))
        assert original['teacher_best_epoch']<=a.teacher_epochs
        bestepoch=original['teacher_best_epoch'];best=original['teacher_val_nmse_db']
        beststate=torch.load(source,map_location='cpu',weights_only=True)
        model.load_state_dict(beststate)
        config['teacher_stage_checkpoint']=str(source);config['teacher_stage_checkpoint_sha256']=sha(source)
        config['teacher_adam_state']='fresh Adam; original teacher optimizer state was not retained' if a.continue_teacher else 'no teacher updates'
        (out/'config.json').write_text(json.dumps(config,indent=2),encoding='utf-8')
    first=bestepoch+1 if a.teacher_checkpoint is not None else 1
    teacher_iterations=range(first,a.teacher_epochs+1) if (a.teacher_checkpoint is None or a.continue_teacher) else ()
    for epoch in teacher_iterations:
        tick=time.monotonic();model.train()
        for i in orders[epoch-1]:
            opt.zero_grad();loss=teacher_loss(tr[i:i+1],teacher_train[i:i+1]);loss.backward();opt.step()
        model.eval()
        with torch.no_grad():score=float(10*torch.log10(teacher_loss(va,teacher_val)))
        if score<best:best=score;bestepoch=epoch;beststate=copy.deepcopy(model.state_dict())
        row=dict(stage='teacher',epoch=epoch,val_teacher_nmse_db=score,best_epoch=bestepoch,seconds=time.monotonic()-tick)
        history.append(row);print(json.dumps(row),flush=True)
        torch.save({'stage':'teacher','epoch':epoch,'model':model.state_dict(),'optimizer':opt.state_dict(),'best':best,'beststate':beststate,'bestepoch':bestepoch},folder/'progress.pt')
        (folder/'history.json').write_text(json.dumps(history,indent=2),encoding='utf-8')
    model.load_state_dict(beststate);teacher_epoch=bestepoch
    torch.save(model.state_dict(),folder/'teacher_checkpoint.pt')
    teacher_range_train=audit(tr);teacher_range_val=audit(va)
    # PA loss sees raw output; no hidden runtime output clipping is introduced.
    with torch.no_grad():initial_pa=float(10*torch.log10(pa_loss(va)))
    bestpa=float('inf');bestpa_state=None;bestpa_epoch=None
    if max(teacher_range_train['max_amplitude'],teacher_range_val['max_amplitude'])<=a.pa_range_max:
        bestpa=initial_pa;bestpa_state=copy.deepcopy(model.state_dict());bestpa_epoch=0
    opt=torch.optim.Adam(model.parameters(),lr=0.00025)
    for epoch in range(1,a.pa_epochs+1):
        tick=time.monotonic();model.train()
        for i in orders[a.teacher_epochs+epoch-1]:
            opt.zero_grad();loss=pa_loss(tr[i:i+1]);loss.backward();opt.step()
        model.eval()
        with torch.no_grad():score=float(10*torch.log10(pa_loss(va)))
        train_range=audit(tr);val_range=audit(va)
        eligible=max(train_range['max_amplitude'],val_range['max_amplitude'])<=a.pa_range_max
        if eligible and score<bestpa:bestpa=score;bestpa_epoch=epoch;bestpa_state=copy.deepcopy(model.state_dict())
        row=dict(stage='pa',epoch=epoch,val_pa_nmse_db=score,eligible=eligible,
                 train_range=train_range,val_range=val_range,best_eligible_epoch=bestpa_epoch,seconds=time.monotonic()-tick)
        history.append(row);print(json.dumps(row),flush=True)
        torch.save({'stage':'pa','epoch':epoch,'model':model.state_dict(),'optimizer':opt.state_dict(),'best':bestpa,'beststate':bestpa_state,'bestepoch':bestpa_epoch},folder/'progress.pt')
        (folder/'history.json').write_text(json.dumps(history,indent=2),encoding='utf-8')
    # If none are in range, preserve best teacher stage and label unavailable.
    eligible=bestpa_state is not None
    if eligible:model.load_state_dict(bestpa_state)
    else:model.load_state_dict(torch.load(folder/'teacher_checkpoint.pt',map_location='cpu',weights_only=True))
    model.eval();torch.save(model.state_dict(),folder/'best_checkpoint.pt')
    with torch.no_grad():
        output=model(te);prediction=pa(protect_zero(output)).numpy();target=(te*gain).numpy()
        teacher_pred=pa(protect_zero(teacher_test)).numpy()
        test_distill=float(metrics.NMSE(output.numpy(),teacher_test.numpy()))
    common=dict(nperseg=seg,bw_main_ch=spec['bw_main_ch'],n_sub_ch=spec['n_sub_ch'])
    def metricsrow(y):
        l,r=metrics.ACLR(y,fs=spec['input_signal_fs'],**common)
        return dict(nmse_db=float(metrics.NMSE(y,target)),evm_db=float(metrics.EVM(y,target,sample_rate=spec['input_signal_fs'],**common)),acpr_l_dbc=float(l),acpr_r_dbc=float(r))
    score=metricsrow(prediction);baseline=metricsrow(teacher_pred)
    np.savetxt(folder/'selected_test_out.txt',output.numpy().reshape(-1,2),fmt='%.12g')
    np.savetxt(folder/'test_input.txt',te.numpy().reshape(-1,2),fmt='%.12g')
    core=copy.deepcopy(model.core);core.fc_out=copy.deepcopy(model.head);params=core.hardware_parameters()
    sp=importlib.util.spec_from_file_location('pack',ROOT/'v4.6_fastgrnn_outpipe/scripts/pack_parameters.py');packer=importlib.util.module_from_spec(sp);sp.loader.exec_module(packer)
    hardware={name:quantize(torch.tensor(params[name]),bits,integer).tolist() for name,shape,bits,integer,unit in packer.GROUPS}
    (folder/'parameters_float.json').write_text(json.dumps(params,indent=2),encoding='utf-8')
    (folder/'parameters_hardware.json').write_text(json.dumps(hardware,indent=2),encoding='utf-8')
    (folder/'parameters.txt').write_text(packer.pack(hardware),encoding='utf-8')
    result=dict(teacher_best_epoch=teacher_epoch,teacher_val_nmse_db=best,
                teacher_train_range=teacher_range_train,teacher_val_range=teacher_range_val,
                pa_initial_val_nmse_db=initial_pa,eligible=eligible,pa_selected_epoch=bestpa_epoch,
                selected_test=score,teacher_test=baseline,test_output_teacher_nmse_db=test_distill,
                selected_train_range=audit(tr),selected_val_range=audit(va),selected_test_range=audit(te),
                elapsed_seconds=time.monotonic()-started,selection_note='If no eligible PA checkpoint, teacher checkpoint reported as diagnostic and eligible=false.')
    (out/'results.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print('DONE',json.dumps(result),flush=True)

if __name__=='__main__':main()
