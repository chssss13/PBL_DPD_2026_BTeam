from pathlib import Path
import json, math
p=Path(__file__).resolve().parent
def read(name):
    return [[float(v) for v in line.split()] for line in (p/name).read_text().splitlines() if line.strip()]
a,b=read('cosim_out.txt'),read('hls_out.txt')
assert len(a)==len(b)==7680 and all(len(row)==2 for row in a+b)
assert all(math.isfinite(v) for row in a+b for v in row)
n=sum(round(x*4096)!=round(y*4096) for u,v in zip(a,b) for x,y in zip(u,v))
result=dict(samples=len(a),q12_mismatches=n,reference='hls_out.txt',pass_check=n==0)
(p/'cosim_comparison.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
assert n==0, 'C-sim mismatch; synthesis blocked'

report=(p/'prj/sol1/sim/report/ResGRU_cosim.rpt').read_text()
assert '|      Pass|' in report, 'RTL co-simulation did not pass'
row=next(line for line in report.splitlines() if '|   Verilog|' in line)
cols=[part.strip() for part in row.split('|') if part.strip()]
interval_max=int(cols[7])
assert interval_max <= 134, f'Call interval regressed: {interval_max} > parent 134'
result['cosim_latency_max']=int(cols[4])
result['cosim_interval_max']=interval_max
(p/'cosim_comparison.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
