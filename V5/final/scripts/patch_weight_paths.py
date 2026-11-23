"""Apply the validated one-stage W/U bypass to a matching raw HLS RTL directory.

The output must be a new directory. Re-run C/RTL verification after applying:
the pattern match ensures structure, not transaction-level correctness.
"""
import argparse
import re
import shutil
from collections import Counter
from pathlib import Path

ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--input',type=Path,required=True)
ap.add_argument('--out',type=Path,required=True)
a=ap.parse_args()
src=a.input.resolve();dst=a.out.resolve()
if not src.is_dir() or dst.exists():ap.error('Input must exist and output must be new')
if src==dst or src in dst.parents:ap.error('Output must be outside input directory')
filename='ResFastGRNN_Loop_LOOP_T_proc.v'
original=(src/filename).read_text(encoding='utf-8')
pattern=re.compile(r'(\.p_read\d+\()(([WU])_([012])_([0-4])_([0-4])_read_reg_\d+)_pp0_iter([235])_reg(\))')
counts=Counter();seen=set()
def replace(m):
    matrix,layer,row,col,stage=m.group(3,4,5,6,7)
    if stage!={'0':'2','1':'3','2':'5'}[layer]:raise RuntimeError('Unexpected delay stage')
    key=(matrix,layer,row,col)
    if key in seen:raise RuntimeError('Duplicate connection')
    seen.add(key);counts[(layer,matrix)]+=1
    return m.group(1)+m.group(2)+'_pp0_iter'+str(int(stage)-1)+'_reg'+m.group(8)
modified=pattern.sub(replace,original)
expected={(str(l),m):25 for l in range(3) for m in ('W','U')}
if dict(counts)!=expected:raise RuntimeError(f'Unexpected W/U mapping: {counts}')
shutil.copytree(src,dst)
(dst/filename).write_text(modified,encoding='utf-8',newline='\n')
print(f'Wrote {dst}: shortened {len(seen)} W/U connections by one stage')
