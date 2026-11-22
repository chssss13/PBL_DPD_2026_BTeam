"""Evaluate the trained FastGRNN HLS C-sim output through the frozen PA."""
import argparse
import json
import os
import sys
from pathlib import Path

import numpy as np
import torch
from finetune_output_fc import OPENDPD, PACKAGE
from compare_full_models import protect_zero


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--run',type=Path,required=True)
    a=ap.parse_args();run=a.run.resolve()
    config=json.loads((run/'config.json').read_text(encoding='utf-8'))
    os.chdir(OPENDPD)
    sys.path.insert(0,str(PACKAGE/'tools'));sys.path.insert(0,str(OPENDPD))
    from eval_pa import models,load_dataset,metrics
    torch.set_num_threads(2)
    pa=models.CoreModel(2,8,1,'dgru')
    path,=(OPENDPD/'save/DPA_200MHz/train_pa').glob('*.pt')
    pa.load_state_dict(torch.load(path,map_location='cpu',weights_only=True))
    pa.eval().requires_grad_(False)
    *_,test,_=load_dataset('DPA_200MHz')
    spec=json.loads((OPENDPD/'datasets/DPA_200MHz/spec.json').read_text())
    seg=spec['nperseg'];output=np.loadtxt(run/'fastgrnn/hls_test_out.txt',dtype=np.float32)
    assert output.shape==test.shape==(7680,2) and np.isfinite(output).all()
    with torch.no_grad():
        prediction=pa(protect_zero(torch.from_numpy(output.reshape(-1,seg,2)))).numpy()
    target=(test*config['gain']).reshape(-1,seg,2)
    common=dict(nperseg=seg,bw_main_ch=spec['bw_main_ch'],n_sub_ch=spec['n_sub_ch'])
    os.chdir(run)
    left,right=metrics.ACLR(prediction,fs=spec['input_signal_fs'],**common)
    score=dict(nmse_db=float(metrics.NMSE(prediction,target)),
               evm_db=float(metrics.EVM(prediction,target,sample_rate=spec['input_signal_fs'],**common)),
               acpr_l_dbc=float(left),acpr_r_dbc=float(right))
    (run/'fastgrnn/hls_accuracy.json').write_text(json.dumps(score,indent=2),encoding='utf-8')
    print(json.dumps(score,indent=2))


if __name__=='__main__':main()
