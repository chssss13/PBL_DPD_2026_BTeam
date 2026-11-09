"""Integer reference for paper-derived corrected rsqrt seed and reduced NR.

Seed: p(m)=5/4-m/4 plus a tabulated correction on [1,2).
Normalization/de-scaling is the fixed-point adaptation, not an IEEE-float clone.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
import hw_ref_v3 as network


def correction_table(bits=6):
    raw=np.arange(32768,65536,dtype=np.int64)
    m=raw/32768.
    error=1/np.sqrt(m)-(1.25-m/4)
    size=1 << (15-bits)
    # Minimax constant correction per band, selected using the whole mantissa
    # domain rather than the evaluation I/Q dataset.
    values=[]
    for start in range(0,len(raw),size):
        band=error[start:start+size]
        values.append(int(np.floor((float(band.min())+float(band.max()))*.5*131072+.5)))
    return values


def inverse_raw(amp2,steps=1,bits=6,table=None):
    if amp2==0:return 0
    table=correction_table(bits) if table is None else table
    k=int(amp2).bit_length()-1
    m=int(amp2) << (15-k)
    address=(m-32768) >> (15-bits)
    y=(163840-m+table[address]+2) >> 2  # unsigned Q1.15
    for _ in range(steps):
        product=y*((3 << 45)-m*y*y)
        y=min(max((product+(1 << 45)) >> 46,0),65535)
    scale=(13-k)//2
    if k&1:
        return network.quant((y*46341) << scale,31,16,5)
    return network.quant(y << scale,15,16,5)


def feature(i,q,inverse_integer=5,inverse_width=16,*,steps=1,bits=6,table=None):
    assert (inverse_width,inverse_integer)==(16,5)
    a=network.quant(i*i+q*q,24,15,3)
    inv=inverse_raw(a,steps,bits,table)
    amp=network.quant(a*inv,23,15,3)
    return [i,q,amp,network.quant(amp*a,24,15,3),network.quant(q*inv,23,15,3),network.quant(i*inv,23,15,3)]


def calculate(steps=1,bits=6):
    table=correction_table(bits)
    original=network.fex
    network.fex=lambda i,q,integer,width:feature(i,q,integer,width,steps=steps,bits=bits,table=table)
    try:return network.calculate(5,16)
    finally:network.fex=original


if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('--steps',type=int,choices=[1,2,4],default=1)
    ap.add_argument('--seed-bits',type=int,choices=[4,5,6,7],default=6)
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--check',type=Path)
    args=ap.parse_args()
    out=calculate(args.steps,args.seed_bits)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    np.savetxt(args.out,out,fmt='%.12f')
    meta=dict(samples=len(out),nr_steps=args.steps,seed_address_bits=args.seed_bits,
              reference_source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              network_reference_sha256=hashlib.sha256(Path(network.__file__).read_bytes()).hexdigest(),
              scope='Independent Python integer calculation; no HLS output used')
    if args.check:
        expected=np.loadtxt(args.check)
        assert expected.shape==out.shape==(7680,2)
        meta.update(q12_mismatches=int(np.count_nonzero(np.rint(out*4096)!=np.rint(expected*4096))),max_abs_error=float(np.max(np.abs(out-expected))))
    args.out.with_suffix('.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
    print(json.dumps(meta,indent=2))
    if args.check and meta['q12_mismatches']:raise SystemExit(1)
