"""Prepare and verify tanh multipartite on immutable accepted v3.5."""
import difflib
import hashlib
import itertools
import json
from pathlib import Path
import shutil
import subprocess
import sys
from multipartite_reference import construct
from continue_resource_search import remove_failed

ROOT=Path(__file__).resolve().parents[1]
PARENT=ROOT/'experiments/v3.5'
CASE=ROOT/'experiments/v3.6'


def prepare():
    assert not CASE.exists() and not (ROOT/'results/v3.6').exists()
    parent_state=json.loads((ROOT/'results/v3.5/state.json').read_text())
    assert parent_state['disposition']=='accepted' and parent_state['mandatory_conditions_pass']
    # Explore mathematical tanh on the entire Q3.12 input domain, without I/Q fitting.
    best=None;stats=[]
    for alpha in [7,8]:
        chunks=[3,3,2] if alpha==7 else [3,2,2]
        for gammas in itertools.combinations_with_replacement(range(alpha+1),3):
            c=construct(alpha,chunks,gammas,guard=3,name='tanh')
            if c['monotonic'] and c['max_abs_error_lsb']<=4:
                stats.append({k:c[k] for k in ['alpha','chunks','gammas','storage_bits','max_abs_error_lsb','rmse_lsb']})
                if best is None or (c['storage_bits'],c['rmse_lsb'])<(best['storage_bits'],best['rmse_lsb']):best=c
    assert best is not None,'No monotone tanh candidate meets 4-LSB preflight error bound'
    for folder in ['src','tb']:shutil.copytree(PARENT/folder,CASE/folder)
    for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt','implementation_directives.tcl']:
        if (PARENT/name).exists():shutil.copy2(PARENT/name,CASE/name)
    (CASE/'tanh_multipartite.json').write_text(json.dumps(best),encoding='utf-8')
    (CASE/'search_summary.json').write_text(json.dumps(sorted(stats,key=lambda x:(x['storage_bits'],x['rmse_lsb'])),indent=2),encoding='utf-8')
    alpha=best['alpha'];beta=15-alpha
    h='#pragma once\n#include "ap_int.h"\nnamespace tanh_multipartite {\n'
    h+=f'static const ap_int<13> base[{len(best["base"])}]={{'+','.join(map(str,best['base']))+'};\n'
    body=f'''    ap_uint<15> position=data.range(14,0);
    position[14]=!position[14];
    ap_uint<{alpha}> index=position.range(14,{beta});
    ap_uint<16> offset=0;
#pragma HLS ARRAY_PARTITION variable=tanh_multipartite::base complete dim=1
'''
    for i,a in enumerate(best['tables']):
        if not any(a['values']):continue
        bits=a['bits'];g=a['gamma'];shift=a['shift']
        h+=f'static const ap_uint<{a["width"]}> part{i}[{len(a["values"])}]={{'+','.join(map(str,a['values']))+'};\n'
        body+=f'''#pragma HLS ARRAY_PARTITION variable=tanh_multipartite::part{i} complete dim=1
    ap_uint<{g+bits}> address{i}=(ap_uint<{g+bits}>(index >> {alpha-g}) << {bits}) | ap_uint<{g+bits}>(position.range({shift+bits-1},{shift}));
    offset+=tanh_multipartite::part{i}[address{i}];
'''
    h+='}\n';(CASE/'src/tanh_multipartite.h').write_text(h,encoding='utf-8')
    body+='    ap_int<17> result=ap_int<17>(tanh_multipartite::base[index])+ap_int<17>((offset+ap_uint<16>(4)) >> 3);\n    res.range(14,0)=result.range(14,0);\n'
    import re
    p=CASE/'src/activations.h';text='#include "tanh_multipartite.h"\n'+p.read_text(encoding='utf-8')
    text,n=re.subn(r'(void tanh_comb\(data_T data, res_T &res\) \{).*?\n\}',lambda m:m.group(1)+'\n#pragma HLS INLINE off\n#pragma HLS LATENCY min=0 max=0\n'+body+'}',text,count=1,flags=re.S)
    assert n==1;p.write_text(text,encoding='utf-8')
    fixture=CASE/'tanh_expected.txt';fixture.write_text('\n'.join(map(str,best['output']))+'\n',encoding='utf-8')
    p=CASE/'tb/tb_resgru.cpp';text=p.read_text(encoding='utf-8').replace(PARENT.as_posix(),CASE.as_posix())
    test='''
    std::ifstream tanh_reference("FIXTURE");
    for(int raw=-16384;raw<16384;++raw) {
        int expected; if(!(tanh_reference >> expected)) return 40;
        ap_fixed<15,3,AP_RND,AP_SAT> input,output;
        input.range(14,0)=ap_int<15>(raw);
        nnet::tanh_comb<decltype(input),decltype(output),nnet::activ_config>(input,output);
        if(output.to_double()*4096!=expected) return 41;
    }
    std::cout << "Tanh multipartite full input-domain PASS" << std::endl;
'''.replace('FIXTURE',fixture.as_posix())
    assert 'int main(int argc, char** argv) {' in text
    p.write_text(text.replace('int main(int argc, char** argv) {','int main(int argc, char** argv) {'+test),encoding='utf-8')
    cfg=json.loads((PARENT/'config.json').read_text())
    cfg.update(version='v3.6',candidate_id='v3.6',experiment_date='2026-11-11',title='Tanh multipartite table-and-add',parent='Accepted v3.5',parent_version='v3.5',
        parent_state_sha256=hashlib.sha256((ROOT/'results/v3.5/state.json').read_bytes()).hexdigest(),
        reference_script='sehyeon_sequence_reference.py',reference_args=['--config',(CASE/'config.json').as_posix()],
        comparison_output='results/v3.5/evidence/csim/hls_out.txt',baseline_resources=parent_state['resources'],baseline_period_ns=parent_state['timing']['period_ns'],baseline_wns_ns=parent_state['timing']['wns_ns'],
        require_parent_q12_exact=False,force_baseline_q12_exact=False,check_no_added_call_stalls=False,
        paper='https://perso.citi-lab.fr/fdedinec/recherche/publis/2005-TC-Multipartite.pdf',
        paper_scope='IEEE TC 54(3), 2005, Multipartite Table Methods; partial-offset decomposition adapted to tanh with conservative grouped quantized slopes. Entire function-domain selection, not I/Q dataset fitting.',
        method_description=f'최종 v3.5에서 tanh 보간 곱셈만 multipartite 기준값·부분 오프셋 표 합으로 대체한다. alpha={alpha}, chunks={best["chunks"]}, gammas={best["gammas"]}, guard=3. sigmoid multipartite·FEx·recurrent nosat·AreaOptimized_high와 입력 인터페이스는 유지한다.',
        method_code='result = base[index] + ((part0[a0] + part1[a1] + part2[a2] + 4) >> 3);',
        interpretation='tanh 전체 32768 입력, 독립 참조/C/RTL 전체 7680샘플, PA 및 II=2·실제15ns를 검증한다. 근사식이 바뀌므로 부모 bit-exact는 요구하지 않는다. 실제 자원 개선 기준 미달이면 삭제한다.')
    files=[p for folder in ['src','tb'] for p in (CASE/folder).iterdir() if p.is_file()]+[p for p in CASE.iterdir() if p.suffix in ['.txt','.tcl'] or p.name in ['multipartite.json','tanh_multipartite.json']]
    cfg['candidate_sha256']={p.relative_to(CASE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
    (CASE/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
    diff=[]
    for folder in ['src','tb']:
        for p in (CASE/folder).iterdir():
            if not p.is_file():continue
            old=PARENT/folder/p.name
            diff.extend(difflib.unified_diff(old.read_text(encoding='utf-8').splitlines(True) if old.exists() else [],p.read_text(encoding='utf-8').splitlines(True),fromfile='v3.5/'+folder+'/'+p.name,tofile='v3.6/'+folder+'/'+p.name))
    (CASE/'changes.diff').write_text(''.join(diff),encoding='utf-8')
    audit={k:best[k] for k in ['alpha','beta','chunks','gammas','guard','storage_bits','max_abs_error_lsb','rmse_lsb','monotonic']}
    audit.update(base_range=[min(best['base']),max(best['base'])],output_range=[min(best['output']),max(best['output'])],input_interface='unchanged',scope='Whole tanh function domain, not I/Q fitting')
    (CASE/'range_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    (ROOT/'docs/v3.6_tanh_multipartite.md').write_text('# v3.6: tanh multipartite\n\n'+cfg['method_description']+'\n\n## 근거와 근사 오차\n\n'+cfg['paper_scope']+'\n\n[논문 원문]('+cfg['paper']+')\n\n'+json.dumps(audit,ensure_ascii=False,indent=2)+'\n\n## 검증과 판정\n\n'+cfg['interpretation']+'\n\nC/PA → HLS II=2 → 전체 RTL → 실제 P&R 순서로 수행한다. 전체 함수 오차와 PA 정확도는 서로 다른 검증이다. 현재 수치는 사전 함수 분석이며 실제 timing·자원 통과 결과가 아니다. 미달 후보는 실제 삭제하고 최종 측정 수치는 공통 실행 로그에 남긴다.\n',encoding='utf-8')
    print('PREPARED v3.6',json.dumps(audit),flush=True)


if __name__=='__main__':
    prepare()
    subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),'v3.6'],cwd=ROOT.parent)
    p=ROOT/'results/v3.6/state.json';state=json.loads(p.read_text())
    if state.get('disposition')=='discard_pending_delete':
        print('REJECTED v3.6',state.get('error','Resource/timing/PA criteria not met'),flush=True)
        remove_failed('v3.6')
    elif state.get('error'):print('STOP tool error',state['error'],flush=True)
    else:print('FINAL v3.6',state.get('disposition'),flush=True)
