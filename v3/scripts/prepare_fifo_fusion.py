"""Prepare v3.8 without changing the accepted v3.7 artifacts."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
PARENT = ROOT / 'experiments/v3.7'
CASE = ROOT / 'experiments/v3.8'


def prepare():
    assert not CASE.exists() and not (ROOT / 'results/v3.8').exists()
    parent = json.loads((ROOT / 'results/v3.7/state.json').read_text())
    assert parent['disposition'] == 'accepted' and parent['mandatory_conditions_pass']
    cfg = json.loads((PARENT / 'config.json').read_text())
    for rel, digest in cfg['candidate_sha256'].items():
        assert hashlib.sha256((PARENT / rel).read_bytes()).hexdigest() == digest, rel
    for folder in ['src', 'tb']:
        shutil.copytree(PARENT / folder, CASE / folder)
    for name in ['multipartite.json', 'sigmoid_expected.txt', 'inverse_expected.txt',
                 'implementation_directives.tcl', 'fifo_control_base.py']:
        shutil.copy2(PARENT / name, CASE / name)
    shutil.copy2(PARENT / 'rtl_transform.py', CASE / 'depth_one_base.py')
    shutil.copy2(ROOT / 'scripts/fifo_entry_fusion.py', CASE / 'rtl_transform.py')
    tb = CASE / 'tb/tb_resgru.cpp'
    tb.write_text(tb.read_text(encoding='utf-8').replace(PARENT.as_posix(), CASE.as_posix()), encoding='utf-8')
    cfg.update(version='v3.8', candidate_id='v3.8', parent='Accepted v3.7', parent_version='v3.7',
        title='Fuse producer output holding into depth-one FIFO boundary',
        date='2026-11-16', experiment_date='2026-11-16',
        parent_state_sha256=hashlib.sha256((ROOT/'results/v3.7/state.json').read_bytes()).hexdigest(),
        baseline_resources=parent['resources'], baseline_period_ns=parent['timing']['period_ns'],
        baseline_wns_ns=parent['timing']['wns_ns'],
        comparison_output='results/v3.7/evidence/csim/hls_out.txt',
        reference_args=['--config', (CASE/'config.json').as_posix()],
        rtl_transform_marker='// FIFO_ENTRY_FUSION_V1',
        paper='', paper_scope='Own RTL experiment: remove producer output holding registers by holding its terminal computation state under FIFO backpressure.',
        method_description='Preserve v3.7 arithmetic, ports, depth-one payload and shared control. Hold entry producer in terminal state until continue, gate ready by continue, and use live terminal-state results instead of 598 output holding registers. Validate backpressure and changing transaction inputs; no arbitrary-cycle equivalence claim.',
        method_code='Terminal-state stall and producer output holding-register elimination',
        interpretation='Require parent-exact output, PA thresholds, II=2, no added baseline call stalls, routed 15ns setup/hold, no routing errors, FF reduction >=1%, no new BRAM or >1% other resource growth. Keep rejected experiment evidence for diagnosis.')
    files = [p for folder in ['src', 'tb'] for p in (CASE/folder).iterdir() if p.is_file()]
    files += [p for p in CASE.iterdir() if p.suffix in ['.py', '.txt', '.tcl'] or p.name == 'multipartite.json']
    cfg['candidate_sha256'] = {p.relative_to(CASE).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (CASE/'config.json').write_text(json.dumps(cfg, indent=2), encoding='utf-8')
    (CASE/'changes.diff').write_text('C++ arithmetic byte-identical to v3.7.\nEntry output holding registers removed; terminal state waits for continue; ready requires continue.\nFIFO data storage and protocol remain v3.7 depth one.\n', encoding='utf-8')
    print('PREPARED v3.8', flush=True)


if __name__ == '__main__':
    prepare()
