"""Compare DSP full-register scheduling against accepted v3.5."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from continue_resource_search import remove_failed

ROOT=Path(__file__).resolve().parents[1]
CASE=ROOT/'experiments/v3.6'
PARENT=ROOT/'experiments/v3.5'


def prepare():
    assert not CASE.exists() and not (ROOT/'results/v3.6').exists()
    parent=json.loads((ROOT/'results/v3.5/state.json').read_text())
    assert parent['disposition']=='accepted' and parent['mandatory_conditions_pass']
    cfg=json.loads((PARENT/'config.json').read_text())
    for rel,digest in cfg['candidate_sha256'].items():
        assert hashlib.sha256((PARENT/rel).read_bytes()).hexdigest()==digest,rel
    for folder in ['src','tb']:shutil.copytree(PARENT/folder,CASE/folder)
    for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt','implementation_directives.tcl']:
        if (PARENT/name).exists():shutil.copy2(PARENT/name,CASE/name)
    # Keep the arithmetic and top interface byte-identical. Relocate only TB fixture paths.
    p=CASE/'tb/tb_resgru.cpp'
    p.write_text(p.read_text(encoding='utf-8').replace(PARENT.as_posix(),CASE.as_posix()),encoding='utf-8')
    setting=CASE/'candidate_directives.tcl'
    setting.write_text('config_schedule -enable_dsp_full_reg=true\n',encoding='utf-8')
    cfg.update(version='v3.6',candidate_id='v3.6',experiment_date='2026-11-12',title='DSP full-register scheduling enabled',
        parent='Accepted v3.5',parent_version='v3.5',parent_state_sha256=hashlib.sha256((ROOT/'results/v3.5/state.json').read_bytes()).hexdigest(),
        reference_args=['--config',(CASE/'config.json').as_posix()],comparison_output='results/v3.5/evidence/csim/hls_out.txt',
        baseline_resources=parent['resources'],baseline_period_ns=parent['timing']['period_ns'],baseline_wns_ns=parent['timing']['wns_ns'],
        force_baseline_q12_exact=False,require_parent_q12_exact=True,check_no_added_call_stalls=False,dsp_full_reg=True,
        min_ff_improvement_fraction=.01,
        paper='https://docs.amd.com/r/2024.1-English/ug949-vivado-design-methodology/Optimizing-Paths-with-Dedicated-Blocks-and-Macro-Primitives',
        paper_scope='AMD DSP register optimization guidance; HLS enable_dsp_full_reg is tested as a scheduling option, not assumed equivalent to phys_opt_design -dsp_register_opt. No new paper algorithm claimed.',
        method_description='v3.5의 모든 C++ 연산·입력·자료형·recurrent 0클럭 pragma를 유지하고 config_schedule -enable_dsp_full_reg만 false에서 true로 바꾼다. 내부 DSP 레지스터 사용과 주변 fabric FF 감소 가능성을 검증한다. HLS가 실제로 동일 강제 latency 제약 때문에 아무것도 바꾸지 않을 수도 있다.',
        method_code='config_schedule -enable_dsp_full_reg=true',
        interpretation='전체 부모/독립 참조/C/RTL 일치, II=2·15 ns를 필수로 확인한다. FF 1% 이상 감소와 다른 자원 증가 1% 이하·BRAM 신규 사용 없음으로 판정한다. DSP나 LUT만 감소하고 FF가 줄지 않으면 이번 목표의 채택 조건을 만족하지 않는다.')
    cfg.pop('expected_scalar_fifo_depth',None)
    files=[x for folder in ['src','tb'] for x in (CASE/folder).iterdir() if x.is_file()]+[x for x in CASE.iterdir() if x.suffix in ['.txt','.tcl'] or x.name=='multipartite.json']
    cfg['candidate_sha256']={p.relative_to(CASE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (CASE/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
    (CASE/'changes.diff').write_text('--- v3.5/HLS configuration\n+++ v3.6/HLS configuration\n-config_schedule -enable_dsp_full_reg=false\n+config_schedule -enable_dsp_full_reg=true\n',encoding='utf-8')
    source_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (CASE/'src').iterdir() if p.is_file()}
    assert all((PARENT/'src'/n).read_bytes()==(CASE/'src'/n).read_bytes() for n in source_hashes)
    (CASE/'range_audit.json').write_text(json.dumps(dict(source_byte_identical=True,src_sha256=source_hashes,arithmetic='unchanged',top_interface='unchanged',recurrent_zero_cycle_constraints='unchanged',hls_clock_ns=15,uncertainty_ns=1,required_ii=2,ff_target='at least 414 fewer fabric FFs than 41308 baseline'),indent=2),encoding='utf-8')
    (ROOT/'docs/v3.6_dsp_register.md').write_text('# v3.6: DSP 레지스터 활용 설정\n\n'+cfg['method_description']+'\n\n## 근거와 실험 범위\n\n'+cfg['paper_scope']+'\n\n[AMD 공식 가이드]('+cfg['paper']+')\n\n소스·입력은 동일하지만 HLS 스케줄이 달라질 수 있으므로 C·독립 참조·PA·합성·전체 RTL·배치배선을 새로 수행한다. 설정 변경만으로 FF 감소 또는 II=2 유지를 가정하지 않는다.\n\n## 판정\n\n'+cfg['interpretation']+'\n\n기준 미달 후보는 실제 삭제하고 최종 수치는 공통 로그에 남긴다. v3.5는 보존한다. [진행표](../results/batch/SUMMARY.md).\n',encoding='utf-8')
    print('PREPARED v3.6; C++ byte-identical, DSP full-register true; FF target >=414',flush=True)


if __name__=='__main__':
    prepare()
    subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),'v3.6'],cwd=ROOT.parent)
    state=json.loads((ROOT/'results/v3.6/state.json').read_text())
    if state.get('disposition')=='discard_pending_delete':
        print('REJECTED v3.6',state.get('error','FF/timing/resource criteria not met'),flush=True)
        remove_failed('v3.6')
    elif state.get('error'):print('STOP tool error',state['error'],flush=True)
    else:print('FINAL',state.get('disposition'),flush=True)
