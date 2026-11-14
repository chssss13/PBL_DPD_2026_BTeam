"""Sequential, lossless FIFO-control sharing trials on accepted v3.5."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from continue_resource_search import remove_failed
from fifo_control_share import audit

ROOT=Path(__file__).resolve().parents[1]
PARENT=ROOT/'experiments/v3.5'
CASE=ROOT/'experiments/v3.6'


def prepare(group_size):
    assert not CASE.exists() and not (ROOT/'results'/CASE.name).exists()
    cfg=json.loads((PARENT/'config.json').read_text())
    parent=json.loads((ROOT/'results/v3.5/state.json').read_text())
    assert parent['disposition']=='accepted' and parent['mandatory_conditions_pass']
    for rel, digest in cfg['candidate_sha256'].items():
        assert hashlib.sha256((PARENT/rel).read_bytes()).hexdigest()==digest, rel
    baseline_rtl=PARENT/'prj_candidate/sol1/syn/verilog'
    assert len(audit((baseline_rtl/'ResGRU.v').read_text(),baseline_rtl))==598
    for folder in ['src','tb']:shutil.copytree(PARENT/folder,CASE/folder)
    for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt','implementation_directives.tcl']:
        if (PARENT/name).exists():shutil.copy2(PARENT/name,CASE/name)
    tb=CASE/'tb/tb_resgru.cpp'
    tb.write_text(tb.read_text(encoding='utf-8').replace(PARENT.as_posix(),CASE.as_posix()),encoding='utf-8')
    script=(ROOT/'scripts/fifo_control_share.py').read_text(encoding='utf-8')
    script=script.replace("default=32)",f"default={group_size})")
    (CASE/'rtl_transform.py').write_text(script,encoding='utf-8')
    cfg.update(version=CASE.name,candidate_id=CASE.name,title=f'Lockstep scalar FIFO controller sharing: groups of {group_size}',
        parent='Accepted v3.5',parent_version='v3.5',date='2026-11-14',
        parent_state_sha256=hashlib.sha256((ROOT/'results/v3.5/state.json').read_bytes()).hexdigest(),
        baseline_resources=parent['resources'],baseline_period_ns=parent['timing']['period_ns'],baseline_wns_ns=parent['timing']['wns_ns'],
        reference_args=['--config',(CASE/'config.json').as_posix()],comparison_output='results/v3.5/evidence/csim/hls_out.txt',
        force_baseline_q12_exact=False,require_parent_q12_exact=True,check_no_added_call_stalls=True,
        dsp_full_reg=False,min_ff_improvement_fraction=.01,resource_priority=True,
        rtl_transform_marker='// FIFO_CONTROL_SHARE_V1',fifo_controller_group_size=group_size,
        paper='https://www-vlsi.stanford.edu/people/alum/pdf/1208_Kelly_HighLevelDigitalInterfaces.pdf',
        paper_scope='DAC 2012 Removing Overhead from High-Level Interfaces, technical background checked in author dissertation Chapter 3. Explicit lockstep controller sharing is our adaptation; not a reproduction of the SAT reachability algorithm.',
        method_description=f'Preserve all v3.5 C++ and HLS scheduling. Structurally verify 598 FIFO controllers and producer synchronization; share controllers in groups of {group_size} in generated RTL. Preserve individual payload shift registers, width, depth two, read latency, interface, reset and runtime parameter semantics.',
        method_code='Guarded post-HLS RTL pass, applied to both cosimulation and implementation input',
        interpretation='C simulation validates unchanged arithmetic; transformed RTL must independently pass full output comparison. Require II=2, actual 15 ns setup/hold, FF reduction >=414, no new BRAM and other resource growth <=1%. Changed parameters between non-overlapping calls require separate regression before final adoption.')
    cfg.pop('expected_scalar_fifo_depth',None)
    files=[p for folder in ['src','tb'] for p in (CASE/folder).iterdir() if p.is_file()]
    files += [p for p in CASE.iterdir() if p.suffix in ['.txt','.tcl','.py'] or p.name=='multipartite.json']
    cfg['candidate_sha256']={p.relative_to(CASE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (CASE/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
    (CASE/'changes.diff').write_text('C++ source: byte-identical to v3.5\nGenerated RTL: '+cfg['method_description']+'\n',encoding='utf-8')
    (ROOT/f'docs/{CASE.name}_fifo_share.md').write_text(f'# {CASE.name}: 전달 FIFO 제어 공유\n\n'+cfg['method_description']+'\n\n## 논문과 적용 범위\n\n'+cfg['paper_scope']+'\n\n## 검증 기준\n\n'+cfg['interpretation']+f'\n\nRTL 변환 코드와 구조 검증 결과는 experiments/{CASE.name}에 저장한다. C++만 검증한 결과를 RTL 변환 검증으로 간주하지 않는다.\n',encoding='utf-8')
    print('PREPARED',cfg['title'],flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--version',default='v3.6')
    parser.add_argument('--group-size',type=int,choices=[8,32])
    parser.add_argument('--resume',action='store_true')
    args=parser.parse_args()
    import re
    assert re.fullmatch(r'v3\.[1-9][0-9]*',args.version)
    CASE=ROOT/'experiments'/args.version
    os.environ['PYTHONIOENCODING']='utf-8'
    for index,group_size in enumerate([args.group_size] if args.group_size else [32]):
        if not args.resume or index != 0:
            prepare(group_size)
        subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),args.version],cwd=ROOT.parent)
        state=json.loads((ROOT/'results'/args.version/'state.json').read_text())
        if state.get('disposition')=='discard_pending_delete':
            print('REJECTED_REASON',state.get('error','Physical resource/timing criteria failed'),flush=True)
            log=ROOT/'results'/args.version/'csynth/csynth.log'
            if log.exists():
                warnings=[line for line in log.read_text(errors='replace').splitlines() if 'WARNING' in line and any(w in line for w in ['II','depend','port','SCHED'])]
                print('SCHEDULE_WARNINGS',json.dumps(warnings[-30:]),flush=True)
            # A missing RTL transform is an integration error, not a failed technique.
            if any(term in state.get('error','') for term in ['transformed','snapshot changed','Source changed']):
                print('STOP: preserve integration evidence for repair',flush=True)
                break
            remove_failed(args.version)
        else:
            print('FINAL',state.get('disposition'),state.get('error',''),flush=True)
            break
