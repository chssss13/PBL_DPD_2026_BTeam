"""Independent integer reference for sehyeon's final GRU plus our FEx/activation."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import numpy as np
import hw_ref_v3 as network
import seed_reference

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'baselines/sehyeon_176b59b'
original_dot=network.dot
original_table=network.table


def recurrent_wrap_dot(x,row,mode):
    if mode!='recurrent':return original_dot(x,row,mode)
    acc=0
    for a,b in zip(x,row):
        product=network.quant(int(a)*int(b),22,18,3,wrap=True)
        acc=network.quant(acc+product,15,21,6)
    return network.quant(acc,15,18,3)


def expanded_table(path,name,size):
    if name!='sigmoid':return original_table(path,name,size)
    positive=original_table(path,name,128)
    full=[]
    for i in range(128):
        p=positive[127-i];base=p&32767;delta=p>>15
        full.append(((4096-base-delta)&32767)|(delta<<15))
    return full+positive


def calculate(mode):
    network.BASE=BASE
    network.dot=recurrent_wrap_dot
    network.table=expanded_table
    if mode=='seed':
        correction=seed_reference.correction_table(6)
        network.fex=lambda i,q,integer,width:seed_reference.feature(i,q,integer,width,steps=1,bits=6,table=correction)
    return network.calculate(5 if mode=='seed' else 6,16)


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--mode',choices=['baseline','seed'],required=True)
    ap.add_argument('--out',type=Path,required=True);ap.add_argument('--check',type=Path)
    args=ap.parse_args();actual=calculate(args.mode)
    assert actual.shape==(7680,2) and np.isfinite(actual).all()
    args.out.parent.mkdir(parents=True,exist_ok=True);np.savetxt(args.out,actual,fmt='%.12f')
    meta=dict(samples=7680,mode=args.mode,reference_source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope='Independent integer calculation; recurrent product WRAP and exact bias sums; symmetric sigmoid table reconstructed')
    if args.check:
        expected=np.loadtxt(args.check);assert expected.shape==actual.shape
        meta.update(q12_mismatches=int(np.count_nonzero(np.rint(actual*4096)!=np.rint(expected*4096))),max_abs_error=float(np.max(np.abs(actual-expected))))
    args.out.with_suffix('.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
    print(json.dumps(meta,indent=2))
    if args.check and meta['q12_mismatches']:raise SystemExit(1)
