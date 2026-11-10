"""Paper-derived table-and-add activation search and integer network reference."""
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import numpy as np
import hw_ref_v3 as network
import seed_reference

ROOT=Path(__file__).resolve().parents[1]


def construct(alpha,chunks,gammas,guard=3,name='sigmoid'):
    beta=15-alpha
    assert sum(chunks)==beta and len(chunks)==len(gammas)
    x=np.arange((1 << alpha)+1,dtype=np.float64)*(8./(1 << alpha))-4
    exact=1/(1+np.exp(-x)) if name=='sigmoid' else np.tanh(x)
    endpoints=np.floor(exact*4096+.5).astype(np.int64)
    base=endpoints[:-1];delta=np.diff(endpoints)
    pos=np.arange(32768,dtype=np.int64);index=pos >> beta
    accum=np.zeros(32768,dtype=np.int64)
    tables=[];shift=0
    for bits,gamma in zip(chunks,gammas):
        group=1 << (alpha-gamma)
        # Conservative slopes keep each segment below its right endpoint,
        # preserving monotonicity at segment boundaries after rounding.
        slope=delta.reshape(-1,group).min(axis=1)
        values=(slope[:,None]*np.arange(1 << bits,dtype=np.int64)[None,:]*(1 << (shift+guard))) >> beta
        address=((index >> (alpha-gamma)) << bits) | ((pos >> shift)&((1 << bits)-1))
        accum+=values.reshape(-1)[address]
        width=max(1,int(values.max()).bit_length())
        tables.append(dict(bits=bits,gamma=gamma,shift=shift,width=width,values=values.reshape(-1).tolist()))
        shift+=bits
    out=base[index]+((accum+(1 << (guard-1))) >> guard)
    raw=np.arange(-16384,16384,dtype=np.int64)/4096
    target=np.floor((1/(1+np.exp(-raw)) if name=='sigmoid' else np.tanh(raw))*4096+.5).astype(np.int64)
    error=out-target
    base_width=12 if name=='sigmoid' else 13
    storage=len(base)*base_width+sum(len(t['values'])*t['width'] for t in tables if any(t['values']))
    return dict(function=name,alpha=alpha,beta=beta,guard=guard,chunks=list(chunks),gammas=list(gammas),
                base_width=base_width,base=base.tolist(),tables=tables,storage_bits=storage,
                max_abs_error_lsb=int(np.max(np.abs(error))),rmse_lsb=float(np.sqrt(np.mean(error*error))),
                monotonic=bool(np.all(np.diff(out)>=0)),output=out.tolist())


def search():
    candidates=[]
    for alpha in [6,7,8]:
        beta=15-alpha
        chunks={9:[3,3,3],8:[3,3,2],7:[3,2,2]}[beta]
        for gammas in itertools.product(range(0,alpha+1),repeat=3):
            if not gammas[0]<=gammas[1]<=gammas[2]:continue
            c=construct(alpha,chunks,gammas)
            if c['monotonic'] and c['max_abs_error_lsb']<=4:
                candidates.append(c)
    assert candidates,'No monotone multipartite candidate meets the preflight error bound'
    candidates.sort(key=lambda c:(c['storage_bits'],c['rmse_lsb']))
    return candidates[0],candidates


def calculate(config):
    original_fex=network.fex;original_activate=network.activate
    table=seed_reference.correction_table(6)
    network.fex=lambda i,q,integer,width:seed_reference.feature(i,q,integer,width,steps=1,bits=6,table=table)
    output=config['output']
    def activation(raw,entries):
        is_tanh=bool(entries[0]&16384)
        replace=is_tanh if config['function']=='tanh' else not is_tanh
        return output[raw+16384] if replace else original_activate(raw,entries)
    network.activate=activation
    try:return network.calculate(5,16)
    finally:network.fex=original_fex;network.activate=original_activate


if __name__=='__main__':
    ap=argparse.ArgumentParser()
    ap.add_argument('--config',type=Path,required=True)
    ap.add_argument('--search',action='store_true')
    ap.add_argument('--out',type=Path)
    ap.add_argument('--check',type=Path)
    args=ap.parse_args()
    if args.search:
        config,candidates=search()
        args.config.parent.mkdir(parents=True,exist_ok=True)
        args.config.write_text(json.dumps(config),encoding='utf-8')
        stats=[{k:c[k] for k in ['alpha','chunks','gammas','storage_bits','max_abs_error_lsb','rmse_lsb']} for c in candidates]
        args.config.with_name('search_summary.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
        print(json.dumps(stats[:5],indent=2))
    config=json.loads(args.config.read_text(encoding='utf-8'))
    if args.out:
        actual=calculate(config)
        args.out.parent.mkdir(parents=True,exist_ok=True)
        np.savetxt(args.out,actual,fmt='%.12f')
        meta=dict(samples=len(actual),reference_source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  table_config_sha256=hashlib.sha256(args.config.read_bytes()).hexdigest(),scope='Independent Python integer calculation; no C output used')
        if args.check:
            expected=np.loadtxt(args.check)
            assert actual.shape==expected.shape==(7680,2)
            meta.update(q12_mismatches=int(np.count_nonzero(np.rint(actual*4096)!=np.rint(expected*4096))),max_abs_error=float(np.max(np.abs(actual-expected))))
        args.out.with_suffix('.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
        print(json.dumps(meta,indent=2))
        if args.check and meta['q12_mismatches']:raise SystemExit(1)
