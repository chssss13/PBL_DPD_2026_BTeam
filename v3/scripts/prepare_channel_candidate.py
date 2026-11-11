"""Prepare a channel-depth experiment with the v3.3 input interface intact."""
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
PARENT=ROOT/'experiments/v3.3'
CASE=ROOT/'experiments/v3.4'
assert not CASE.exists(), 'Refusing to overwrite a candidate'
state=json.loads((ROOT/'results/v3.3/state.json').read_text(encoding='utf-8'))
assert state['disposition']=='accepted' and state['mandatory_conditions_pass']

# Read generated RTL; do not infer FIFO sizes from aggregate SRL counts.
rtl=PARENT/'prj_candidate/sol1/syn/verilog'
inventory={}
for file in rtl.glob('*.v'):
    for width,depth,instance in re.findall(r'^ResGRU_fifo_w(\d+)_d(\d+)_S\s+(\w+)\s*\(',file.read_text(),re.M):
        key=(int(width),int(depth));inventory[key]=inventory.get(key,0)+1
assert inventory, 'No generated FIFOs found'

for folder in ['src','tb']:
    shutil.copytree(PARENT/folder,CASE/folder)
for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt']:
    shutil.copy2(PARENT/name,CASE/name)
tb=CASE/'tb/tb_resgru.cpp'
tb.write_text(tb.read_text(encoding='utf-8').replace(PARENT.as_posix(),CASE.as_posix()),encoding='utf-8')
directive=CASE/'candidate_directives.tcl'
directive.write_text('# Internal scalar propagation FIFOs only; external ports unchanged.\nconfig_dataflow -scalar_fifo_depth 1\n',encoding='utf-8')
cfg=json.loads((PARENT/'config.json').read_text(encoding='utf-8'))
cfg.update(version='v3.4',candidate_id='v3.4',title='Internal scalar propagation FIFO depth 2 to 1',parent='Accepted v3.3',
    parent_state_sha256=hashlib.sha256((ROOT/'results/v3.3/state.json').read_bytes()).hexdigest(),
    comparison_output='results/v3.3/evidence/csim/hls_out.txt',baseline_resources=state['resources'],
    baseline_period_ns=state['timing']['period_ns'],baseline_wns_ns=state['timing']['wns_ns'],
    reference_args=['--config',(CASE/'multipartite.json').as_posix()],require_parent_q12_exact=True,expected_scalar_fifo_depth=1,check_no_added_call_stalls=True,
    paper='https://zjru.github.io/camera_ready/zhao_tcad19.pdf',
    paper_scope='IEEE TCAD 39(7), 2020, COMBA dataflow-channel/directive interaction analysis; scalar FIFO depth 1 is our experimental choice, not a result claimed in the paper')
files=[p for folder in ['src','tb'] for p in (CASE/folder).iterdir() if p.is_file()]
files += [CASE/name for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt','candidate_directives.tcl']]
cfg['candidate_sha256']={p.relative_to(CASE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(CASE/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
audit=dict(interface='Unchanged source headers and top function; runtime weights and I/Q unchanged',
    arithmetic='Identical to accepted v3.3',fifo_inventory=[dict(width=w,depth=d,instances=n) for (w,d),n in sorted(inventory.items())],
    candidate='scalar_fifo_depth 1; other FIFO categories and DATAFLOW retained',
    checks='Must verify generated depth actually changes; exact parent C and RTL, II=2, no deadlock, call interval/total cycles, routed 15ns and resource reduction')
(CASE/'range_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
(CASE/'changes.diff').write_text(''.join(difflib.unified_diff([],directive.read_text().splitlines(True),fromfile='v3.3/default',tofile='v3.4/candidate_directives.tcl')),encoding='utf-8')
print(json.dumps(audit,indent=2))
if '--run' in sys.argv:
    completed=subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),'v3.4'],cwd=ROOT.parent)
    result=ROOT/'results/v3.4/state.json'
    status=json.loads(result.read_text(encoding='utf-8')) if result.exists() else {}
    if status.get('disposition')=='discard_pending_delete':
        print('Rejected v3.4:',status.get('error','Resource/timing screening failed'),flush=True)
        targets=[CASE,ROOT/'results/v3.4',ROOT/'docs/v3.4_scalar_fifo.md']
        commands=["$ErrorActionPreference='Stop'"]
        for target in targets:
            target=target.resolve()
            assert target.is_relative_to(ROOT.resolve()) and not target.is_symlink()
            if target.exists():
                literal=str(target).replace("'","''")
                commands.append(f"Remove-Item -LiteralPath '{literal}'"+(' -Recurse' if target.is_dir() else ''))
        subprocess.run(['powershell','-NoProfile','-Command','\n'.join(commands)],check=True)
        from candidate_summary import render
        render()
        print('Rejected candidate files deleted; v3.3 preserved',flush=True)
    elif status.get('error'):
        print('Tool error: inspect results/v3.4 before proceeding',flush=True)
