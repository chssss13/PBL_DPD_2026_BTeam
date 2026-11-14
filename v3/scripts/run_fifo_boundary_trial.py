"""Remove only the top-level dataflow boundary; retain the sample pipeline."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from continue_resource_search import remove_failed

ROOT = Path(__file__).resolve().parents[1]
PARENT = ROOT / 'experiments/v3.5'
CASE = ROOT / 'experiments/v3.6'


def prepare():
    assert not CASE.exists() and not (ROOT/'results/v3.6').exists()
    parent = json.loads((ROOT/'results/v3.5/state.json').read_text())
    assert parent['disposition'] == 'accepted' and parent['mandatory_conditions_pass']
    cfg = json.loads((PARENT/'config.json').read_text())
    for rel, digest in cfg['candidate_sha256'].items():
        assert hashlib.sha256((PARENT/rel).read_bytes()).hexdigest() == digest, rel
    for folder in ['src', 'tb']:
        shutil.copytree(PARENT/folder, CASE/folder)
    for name in ['multipartite.json', 'sigmoid_expected.txt', 'inverse_expected.txt', 'implementation_directives.tcl']:
        if (PARENT/name).exists():
            shutil.copy2(PARENT/name, CASE/name)
    tb = CASE/'tb/tb_resgru.cpp'
    tb.write_text(tb.read_text(encoding='utf-8').replace(PARENT.as_posix(), CASE.as_posix()), encoding='utf-8')
    src = CASE/'src/multi_gru.cpp'
    before = src.read_text(encoding='utf-8')
    prefix, body = before.split('void ResGRU(', 1)
    assert body.count('#pragma HLS DATAFLOW') == 1
    body = body.replace('#pragma HLS DATAFLOW', '// Single scheduling region: keep LOOP_T pipelined at II=2.', 1)
    after = prefix + 'void ResGRU(' + body
    src.write_text(after, encoding='utf-8')
    (CASE/'changes.diff').write_text(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='v3.5/src/multi_gru.cpp', tofile='v3.6/src/multi_gru.cpp')), encoding='utf-8')
    cfg.update(version='v3.6', candidate_id='v3.6', title='Remove top-level scalar propagation FIFO boundary',
        parent='Accepted v3.5', date='2026-11-14',
        parent_state_sha256=hashlib.sha256((ROOT/'results/v3.5/state.json').read_bytes()).hexdigest(),
        baseline_resources=parent['resources'], baseline_period_ns=parent['timing']['period_ns'], baseline_wns_ns=parent['timing']['wns_ns'],
        comparison_output='results/v3.5/evidence/csim/hls_out.txt',
        reference_script='sehyeon_sequence_reference.py', reference_args=['--config', (CASE/'config.json').as_posix()],
        require_parent_q12_exact=True, force_baseline_q12_exact=False, dsp_full_reg=False,
        min_ff_improvement_fraction=0.01, check_no_added_call_stalls=True,
        paper='https://zjru.github.io/camera_ready/zhao_tcad19.pdf',
        paper_scope='COMBA, IEEE TCAD: dataflow/directive design-space context. Removing this particular boundary is our hypothesis, not a result established by the paper.',
        method_description='Remove only ResGRU top-level DATAFLOW. Preserve its function signature, runtime parameter ports, arithmetic, types, reset semantics, and LOOP_T II=2 directive. Test whether the entry-to-loop propagation FIFOs are eliminated without replacement FF growth.',
        method_code='Remove ResGRU/#pragma HLS DATAFLOW; retain LOOP_T pipeline II=2',
        interpretation='Require full parent/reference/RTL exactness, PA thresholds, II=2, routed 15 ns, at least 414 fewer FFs, other resource increases at most 1%, and no new BRAM. Verify external interface metadata and generated FIFO inventory before adoption.')
    cfg.pop('expected_scalar_fifo_depth', None)
    files = [p for folder in ['src', 'tb'] for p in (CASE/folder).iterdir() if p.is_file()]
    files += [p for p in CASE.iterdir() if p.suffix in ['.txt', '.tcl'] or p.name == 'multipartite.json']
    cfg['candidate_sha256'] = {p.relative_to(CASE).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (CASE/'config.json').write_text(json.dumps(cfg, indent=2), encoding='utf-8')
    (ROOT/'docs/v3.6_fifo_boundary.md').write_text('# v3.6: 전달 FIFO 경계 제거\n\n'+cfg['method_description']+'\n\n## 기준\n\n'+cfg['interpretation']+'\n\n기존 routed 보고서: 전달 FIFO 598개, LUT 9,649개, FF 20,540개. 이 수치는 절감 예상치가 아니다. 경계 제거 후 연산부 저장 레지스터와 인터페이스 변경 여부를 별도로 검증한다.\n', encoding='utf-8')
    print('PREPARED v3.6: remove only top DATAFLOW; baseline FIFO count 598, FF 20540; FF target >=414', flush=True)


if __name__ == '__main__':
    prepare()
    subprocess.run([sys.executable, str(ROOT/'scripts/run_flow.py'), 'v3.6'], cwd=ROOT.parent)
    state = json.loads((ROOT/'results/v3.6/state.json').read_text())
    if state.get('disposition') == 'discard_pending_delete':
        print('REJECTED', state.get('error', 'Acceptance criteria failed'), flush=True)
        remove_failed('v3.6')
    else:
        print('FINAL', state.get('disposition'), state.get('error', ''), flush=True)
