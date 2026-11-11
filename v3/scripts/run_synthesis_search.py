"""Final bounded synthesis-directive comparison on identical accepted v3.3 RTL."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from continue_resource_search import remove_failed

ROOT=Path(__file__).resolve().parents[1]
PARENT='v3.3'


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(version,directive):
    parent=ROOT/'experiments'/PARENT;case=ROOT/'experiments'/version
    evidence=ROOT/'results'/PARENT/'evidence';out=ROOT/'results'/version
    assert not case.exists() and not out.exists()
    pstate=json.loads((ROOT/'results'/PARENT/'state.json').read_text())
    assert pstate['disposition']=='accepted' and pstate['mandatory_conditions_pass']
    cfg=json.loads((parent/'config.json').read_text())
    for rel,digest in cfg['candidate_sha256'].items():
        assert sha(parent/rel)==digest,rel
    for folder in ['src','tb']:
        shutil.copytree(parent/folder,case/folder)
    for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt']:
        shutil.copy2(parent/name,case/name)
    setting=case/'implementation_directives.tcl'
    setting.write_text(f'config_export -vivado_synth_design_args {{-directive {directive}}}\n',encoding='utf-8')
    cfg.update(version=version,candidate_id=version,parent='Accepted v3.3 (identical C++ and HLS RTL)',parent_version=PARENT,
        parent_state_sha256=sha(ROOT/'results'/PARENT/'state.json'),experiment_date='2026-11-10',
        title='Vivado synthesis directive '+directive,vivado_synth_directive=directive,
        comparison_output='results/v3.3/evidence/csim/hls_out.txt',baseline_resources=pstate['resources'],
        baseline_period_ns=pstate['timing']['period_ns'],baseline_wns_ns=pstate['timing']['wns_ns'],
        reference_args=['--config',(case/'multipartite.json').as_posix()],require_parent_q12_exact=True,
        paper='https://docs.amd.com/r/2024.1-English/ug901-vivado-synthesis/Using-Synthesis-Settings',
        paper_scope='AMD Vivado 2024.1 UG901 and HLS UG1399 config_export. Tool configuration experiment, not a new paper-derived algorithm. AreaOptimized_high overlaps with the strategy used on sehyeon.',
        method_description=f'v3.3 C++·입력·HLS RTL·II·15 ns·uncertainty를 고정하고 Vivado synth_design directive만 sdx_optimization_effort_high에서 {directive}로 바꾼다. 구현 전략은 default를 유지한다.',
        method_code=f'config_export -vivado_synth_design_args {{-directive {directive}}}',
        interpretation='설정에 따른 실제 LUT/FF/DSP/BRAM 및 setup/hold를 비교한다. 세현의 합성 전략 실험과 겹치는 항목임을 명시한다. 기준 미달은 삭제하고, 실제 수치는 삭제 전 공통 로그의 FINAL_METRICS에 남긴다.')
    files=[x for folder in ['src','tb'] for x in (case/folder).iterdir() if x.is_file()]+[case/x for x in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt','implementation_directives.tcl']]
    cfg['candidate_sha256']={x.relative_to(case).as_posix():sha(x) for x in files}
    (case/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
    (case/'changes.diff').write_text('--- v3.3/export setting\n+++ '+version+'/export setting\n- -directive sdx_optimization_effort_high\n+ -directive '+directive+'\n',encoding='utf-8')

    # Clone synthesized HLS artifacts only. Exclude old Vivado projects/results.
    project=parent/'prj_candidate'
    shutil.copytree(project,case/'prj_candidate',ignore=shutil.ignore_patterns('impl','sim','csim','.debug','*.log','*.jou'))
    for name in ['hls.app','sol1/sol1.aps','sol1/sol1.directive']:
        file=case/'prj_candidate'/name
        if file.exists():file.write_text(file.read_text(encoding='utf-8').replace(parent.as_posix(),case.as_posix()).replace(str(parent),str(case)),encoding='utf-8')
    original_rtl=parent/'prj_candidate/sol1/syn/verilog'
    copied_rtl=case/'prj_candidate/sol1/syn/verilog'
    hashes={x.relative_to(original_rtl).as_posix():sha(x) for x in original_rtl.rglob('*') if x.is_file()}
    assert hashes and all(sha(copied_rtl/rel)==digest for rel,digest in hashes.items())
    # The copied HLS DB may regard RTL generation as cached and expect impl RTL.
    # Seed only identical generated RTL, never the parent's Vivado run/checkpoint.
    for language in ['verilog','vhdl']:
        source=case/'prj_candidate/sol1/syn'/language
        if source.exists():
            shutil.copytree(source,case/'prj_candidate/sol1/impl'/language,dirs_exist_ok=True)
    (case/'range_audit.json').write_text(json.dumps(dict(source_and_tb_byte_identical=True,hls_rtl_sha256=hashes,validation_inherited_from=PARENT,
        fresh_runs=['Vivado synthesis','place and route','final reports'],clock_ns=15,hls_uncertainty_ns=1,ii=2,directive=directive),indent=2),encoding='utf-8')
    out.mkdir(parents=True)
    for stage in ['csim','csynth','cosim','reference']:
        shutil.copytree(evidence/stage,out/stage)
    state={k:v for k,v in pstate.items() if k not in ['resources','timing','resource_delta','mandatory_conditions_pass','disposition','error','settings']}
    state.update(version=version,settings=cfg,completed=['csim','csynth','cosim'],active_stage=None,
        review_required_before_next_version=False,validation_inherited_from=PARENT,
        validation_inheritance_reason='Candidate C++/TB and every synthesized HLS RTL file verified byte-identical to accepted v3.3; only downstream Vivado synthesis settings changed')
    for key in ['hls_out.txt','rtl_out.txt']:
        state[key]['baseline_q12_mismatches']=0;state[key]['baseline_max_abs_error']=0
    state['hls_out.txt'].update(pa_delta_db={k:0. for k in ['NMSE','ACPR_L','ACPR_R']},pa_source='Inherited v3.3 PA; exact same C output and HLS RTL, not freshly evaluated')
    (out/'state.json').write_text(json.dumps(state,indent=2),encoding='utf-8')
    doc=ROOT/'docs'/f'{version}_synthesis_settings.md'
    doc.write_text(f'# {version}: {directive}\n\n'+cfg['method_description']+'\n\nC·PA·HLS·RTL 수치는 byte-identical v3.3의 검증을 계승한다. 새로 실행한 것은 Vivado 합성·배치배선이며 세현과 겹치는 설정 비교 실험이다.\n\n[공식 설정 문서]('+cfg['paper']+')\n\nII=2·15 ns setup/hold·배선 오류 0, 공식 PA와 기존 자원 개선 기준을 유지한다. 미달이면 실제 삭제하고 수치만 공통 실행 로그에 남긴다.\n',encoding='utf-8')
    print('PREPARED',version,directive,'RTL files verified',len(hashes),flush=True)


def main():
    # Both alternatives use the same immutable v3.3 parent; no cumulative changes.
    for directive in ['AreaOptimized_high','AreaOptimized_medium']:
        pending=ROOT/'experiments/v3.4/config.json'
        reuse=False
        if '--resume' in sys.argv and pending.exists():
            current=json.loads(pending.read_text())
            result=ROOT/'results/v3.4/state.json'
            prior=json.loads(result.read_text()) if result.exists() else {}
            reuse=current.get('vivado_synth_directive')==directive and prior.get('disposition')!='accepted'
        if reuse:
            version='v3.4'
            for language in ['verilog','vhdl']:
                source=ROOT/'experiments'/version/'prj_candidate/sol1/syn'/language
                if source.exists():shutil.copytree(source,ROOT/'experiments'/version/'prj_candidate/sol1/impl'/language,dirs_exist_ok=True)
            print('RESUME',version,directive,'restored identical cached implementation RTL',flush=True)
        else:
            accepted=[int(p.name.split('.')[1]) for p in (ROOT/'experiments').glob('v3.*')]
            version='v3.'+str(max(accepted)+1)
            prepare(version,directive)
        subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),version],cwd=ROOT.parent)
        state=json.loads((ROOT/'results'/version/'state.json').read_text())
        if state.get('disposition')=='accepted' and not state.get('error'):
            print('ACCEPTED',version,directive,flush=True)
        elif state.get('disposition')=='discard_pending_delete':
            print('REJECTED',version,directive,flush=True);remove_failed(version)
        else:
            print('STOP unresolved tool error',version,state.get('error'),flush=True);return
    print('Final synthesis setting comparison complete; no further trials queued',flush=True)


if __name__=='__main__':main()
