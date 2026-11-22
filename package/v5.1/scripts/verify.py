"""Verify release digests and archived Q12 C/RTL evidence (stdlib only)."""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re

ROOT=Path(__file__).resolve().parents[1]


def integrity():
    manifest=json.loads((ROOT/'SHA256SUMS.json').read_text(encoding='utf-8'))
    for name,digest in manifest.items():
        path=(ROOT/name).resolve()
        if not path.is_relative_to(ROOT):raise ValueError('Manifest path escapes package: '+name)
        if hashlib.sha256(path.read_bytes()).hexdigest()!=digest:raise ValueError('Digest mismatch: '+name)
    return len(manifest)


def rows(path,n):
    values=[]
    for line in Path(path).read_text().splitlines():
        if not line.strip():continue
        row=list(map(float,line.split()))
        if len(row)!=2 or not all(math.isfinite(v) for v in row):raise ValueError('Invalid I/Q row: '+str(path))
        if any(abs(v*4096-round(v*4096))>1e-6 for v in row):raise ValueError('Not on Q12 grid: '+str(path))
        values.append(tuple(round(v*4096) for v in row))
    if len(values)!=n:raise ValueError(f'{path}: expected {n} samples, got {len(values)}')
    return values


def compare(actual,expected,n):
    a=rows(actual,n);b=rows(expected,n)
    mismatch=sum(x!=y for ra,rb in zip(a,b) for x,y in zip(ra,rb))
    if mismatch:raise ValueError(f'{actual}: {mismatch} Q12 component mismatches')
    return {'samples':n,'Q12_mismatches':mismatch}


def transactions(path,n):
    data=re.findall(r'transaction\s+(\d+):\s+(\d+)\s+(\d+|[xX])\s*$',Path(path).read_text(),re.M)
    count=n//64
    if len(data)!=count or [int(i) for i,_,_ in data]!=list(range(count)):
        raise ValueError('Wrong transaction count or IDs: '+str(path))
    if any(c.lower()=='x' for _,_,c in data[:-1]):raise ValueError('Missing transaction interval')
    latency=max(int(b) for _,b,_ in data[2:]);interval=max(int(c) for _,_,c in data[2:] if c.lower()!='x')
    if latency>144 or interval>134:raise ValueError(f'Call performance regressed: {latency}/{interval}')
    return {'transactions':count,'steady_latency_max':latency,'steady_interval_max':interval}


def archived():
    results={}
    for variant in ['control','candidate']:
        for kind,n in [('standard',7680),('stress',5120)]:
            tag=variant+'_'+kind
            result=compare(ROOT/'reports/native'/(tag+'_out.txt'),ROOT/'reference'/(kind+'_expected.txt'),n)
            result.update(transactions(ROOT/'reports/native'/(tag+'_ResGRU.performance.result.transaction.xml'),n))
            results[tag]=result
    return results


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--archived',action='store_true');args=parser.parse_args()
    result={'verified_files':integrity()}
    if args.archived:result['archived']=archived()
    print(json.dumps(result,indent=2))
