from pathlib import Path
import json, math
p=Path(__file__).resolve().parent
def read(name):
    return [[float(v) for v in line.split()] for line in (p/name).read_text().splitlines() if line.strip()]
a,b=read('hls_out.txt'),read('python_expected.txt')
assert len(a)==len(b)==7680 and all(len(row)==2 for row in a+b)
assert all(math.isfinite(v) for row in a+b for v in row)
n=sum(round(x*4096)!=round(y*4096) for u,v in zip(a,b) for x,y in zip(u,v))
result=dict(samples=len(a),q12_mismatches=n,reference='python_expected.txt',pass_check=n==0)
(p/'csim_comparison.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
assert n==0, 'C-sim mismatch; synthesis blocked'
