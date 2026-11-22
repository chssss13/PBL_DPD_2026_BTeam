"""Export the selected v5 QAT checkpoint; no training is performed."""
from pathlib import Path
import argparse
import json
import math

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
    if args.out.exists():raise RuntimeError('Refusing existing output directory: '+str(args.out))
    import torch
    checkpoint=torch.load(ROOT/'training/best_master.pt',map_location='cpu',weights_only=True)
    state=checkpoint['state_dict'];quantized={};manifest={}
    for name,tensor in state.items():
        if not name.startswith('p.'):continue
        name=name[2:]
        w,i=(15,3) if name.startswith(('b_','L0_b','L1_b','L2_b')) else (14,4)
        scale=2**(w-i);codes=torch.floor(tensor.double()*scale+0.5).clamp(-2**(w-1),2**(w-1)-1)
        values=(codes/scale).reshape(-1).tolist()
        reference=[float(v) for v in (ROOT/'golden/weights'/(name+'.txt')).read_text().split()]
        if len(values)!=len(reference) or any(round(a*scale)!=round(b*scale) for a,b in zip(values,reference)):
            raise RuntimeError('Checkpoint differs from deployed quantized weights: '+name)
        if not all(math.isfinite(v) for v in values):raise RuntimeError('Nonfinite coefficient: '+name)
        quantized[name]=values
        manifest[name]={'shape':list(tensor.shape),'min':min(values),'max':max(values)}
    if len(quantized)!=42 or sum(len(v) for v in quantized.values())!=591:raise RuntimeError('Unexpected parameter layout')
    args.out.mkdir(parents=True)
    for name,values in quantized.items():(args.out/(name+'.txt')).write_text(''.join(format(v,'.17g')+'\n' for v in values))
    manifest['_config']={'H':5,'L':3,'gating_is_sigmoid_applied':True,'version':'v5.1','checkpoint_epoch':checkpoint['epoch']}
    (args.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'files':42,'parameters':591,'deployed_quantized_codes_match':True,'out':str(args.out)},indent=2))


if __name__=='__main__':main()
