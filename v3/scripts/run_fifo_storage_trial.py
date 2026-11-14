"""Fresh v3.7 storage-depth trial on v3.6, sequential tool use."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from continue_resource_search import remove_failed

ROOT=Path(__file__).resolve().parents[1]
PARENT=ROOT/'experiments/v3.6'
CASE=ROOT/'experiments/v3.7'


def prepare():
    assert not CASE.exists() and not(ROOT/'results/v3.7').exists()
    cfg=json.loads((PARENT/'config.json').read_text())
    parent=json.loads((ROOT/'results/v3.6/state.json').read_text())
    assert parent['disposition']=='accepted' and parent['mandatory_conditions_pass']
    for rel,digest in cfg['candidate_sha256'].items():
        assert hashlib.sha256((PARENT/rel).read_bytes()).hexdigest()==digest,rel
    for folder in ['src','tb']:shutil.copytree(PARENT/folder,CASE/folder)
    for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt','implementation_directives.tcl']:
        shutil.copy2(PARENT/name,CASE/name)
    p=CASE/'tb/tb_resgru.cpp';p.write_text(p.read_text(encoding='utf-8').replace(PARENT.as_posix(),CASE.as_posix()),encoding='utf-8')
    shutil.copy2(PARENT/'rtl_transform.py',CASE/'fifo_control_base.py')
    shutil.copy2(ROOT/'scripts/fifo_depth_one.py',CASE/'rtl_transform.py')
    cfg.update(version='v3.7',candidate_id='v3.7',parent='Accepted v3.6',parent_version='v3.6',
        title='Shared scalar FIFO payload capacity two to one',date='2026-11-15',experiment_date='2026-11-15',
        parent_state_sha256=hashlib.sha256((ROOT/'results/v3.6/state.json').read_bytes()).hexdigest(),
        baseline_resources=parent['resources'],baseline_period_ns=parent['timing']['period_ns'],baseline_wns_ns=parent['timing']['wns_ns'],
        comparison_output='results/v3.6/evidence/csim/hls_out.txt',reference_args=['--config',(CASE/'config.json').as_posix()],
        min_ff_improvement_fraction=.01,rtl_transform_marker='// FIFO_DEPTH_ONE_V1',
        check_no_added_call_stalls=True,fifo_payload_depth=1,
        paper='https://arxiv.org/html/2510.20981v1',
        paper_scope='FIFOAdvisor, ASP-DAC 2026: simulation-guided FIFO capacity exploration. Fixed depth-one trial is our adaptation; the paper optimizer and BRAM objective are not reproduced.',
        method_description='Retain v3.6 DATAFLOW, arithmetic, interface ports and 32-channel shared control groups. Reduce all 598 scalar payload FIFOs from depth two to one with capacity-correct full/empty control. This changes backpressure and is not assumed cycle-equivalent for arbitrary overlapping calls.',
        method_code='Post-HLS capacity change with explicit full/empty control, unchanged payload widths',
        interpretation='Require II=2, full C/reference/transformed-RTL exactness, PA thresholds, unchanged measured call interval and total cycles, routed 15 ns setup/hold, no routing errors, FF decrease >=374, no new BRAM or >1% other resource growth. Further weight/reset/stall regressions remain distinct from baseline-vector validation.')
    files=[p for folder in ['src','tb'] for p in (CASE/folder).iterdir() if p.is_file()]
    files += [p for p in CASE.iterdir() if p.suffix in ['.py','.txt','.tcl'] or p.name=='multipartite.json']
    cfg['candidate_sha256']={p.relative_to(CASE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (CASE/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
    (CASE/'changes.diff').write_text('C++ byte-identical to v3.6.\nFIFO payload DEPTH: 2 -> 1; fifo_cap: 2 -> 1; capacity-specific controller.\nBackpressure may change; reject if measured call throughput degrades.\n',encoding='utf-8')
    print('PREPARED v3.7: FIFO capacity 2 -> 1; FF target >=374; parent v3.6 preserved',flush=True)


if __name__=='__main__':
    os.environ['PYTHONIOENCODING']='utf-8'
    if '--resume' not in sys.argv:prepare()
    if not(CASE/'fifo_protocol_test.json').exists():
        subprocess.run([sys.executable,str(ROOT/'scripts/check_fifo_protocol.py'),str(CASE)],check=True,cwd=ROOT.parent)
    subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),'v3.7'],cwd=ROOT.parent)
    state=json.loads((ROOT/'results/v3.7/state.json').read_text())
    error=state.get('error','')
    if state.get('disposition')=='discard_pending_delete':
        print('REJECTED_REASON',error or 'Resource/timing criterion failed',flush=True)
        if any(x in error for x in ['snapshot changed','transformed','source hash']):
            print('STOP: integration error retained for repair',flush=True)
        else:remove_failed('v3.7')
    else:print('FINAL',state.get('disposition'),error,flush=True)
