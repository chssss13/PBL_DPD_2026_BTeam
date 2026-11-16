"""Record integration-only transform repairs, then resume completed HLS work."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CASE = ROOT/'experiments/v3.8'
OUT = ROOT/'results/v3.8'
state = json.loads((OUT/'state.json').read_text())
assert state['completed'] == ['csim','csynth'], state['completed']
assert 'rtl_out.txt' not in state and not (OUT/'cosim/tool_done').exists()
cfg = json.loads((CASE/'config.json').read_text())
old = cfg['candidate_sha256']['rtl_transform.py']
shutil.copy2(ROOT/'scripts/fifo_entry_fusion.py', CASE/'rtl_transform.py')
new = hashlib.sha256((CASE/'rtl_transform.py').read_bytes()).hexdigest()
cfg['candidate_sha256']['rtl_transform.py'] = new
state['settings'] = cfg
repair = dict(reason='Accept whitespace before entry instance opening parenthesis; no C++ or arithmetic change',
    old_transform_sha256=old,new_transform_sha256=new,retained_stages=state['completed'],
    previous_error=state.get('error'))
(OUT/'integration_repair.json').write_text(json.dumps(repair,indent=2))
for path in [CASE/'config.json',OUT/'config.json']:
    path.write_text(json.dumps(cfg,indent=2))
shutil.copy2(CASE/'rtl_transform.py',OUT/'rtl_transform.py')
(OUT/'state.json').write_text(json.dumps(state,indent=2))
subprocess.run([sys.executable,ROOT/'scripts/run_flow.py','v3.8'],check=True,cwd=ROOT.parent)
