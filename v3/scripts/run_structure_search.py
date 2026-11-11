"""Sequential DAC pipeline-boundary and TCAD register-lifetime trials."""
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from continue_resource_search import remove_failed

ROOT=Path(__file__).resolve().parents[1]
METHODS={
 'pipeline': dict(title='Input projection pipeline boundary',paper='https://www.csl.cornell.edu/~zhiruz/pdfs/pipemap-dac2015.pdf',
     paper_scope='DAC 2015, Area-Efficient Pipelining for FPGA-Targeted High-Level Synthesis, DOI 10.1145/2744769.2744801. Mapping-aware boundary principle; our source-level experiment does not reproduce the paper MILP scheduler.',
     method_description='FEx·입력 투영·PReLU를 II=2 함수 경계로 묶는다. recurrent 경로와 외부 입력을 유지하고 기존의 각 형 변환·반올림·포화·누산 순서를 그대로 둔다.',
     method_code='Input_Projection_Stage(IQ_seq[t][0], IQ_seq[t][1], W_inj, b_inj, prelu_param, gru_in);'),
 'lifetime': dict(title='Layer-local intermediate lifetimes',paper='https://escholarship.org/content/qt6q06h45g/qt6q06h45g_noSplash_15b41a8eafdd6af4a14010daac6e8412.pdf',
     paper_scope='IEEE TCAD 25(5), 2006, Optimal Register Sharing for High-Level Synthesis of SSA Form Programs, DOI 10.1109/TCAD.2006.870409. Liveness principle adapted at source level; no replacement of Vitis SSA allocator and no assumption that local variables force hardware sharing.',
     method_description='층별 출력 배열을 해당 층 반복의 지역 중간값으로 바꾸고 최종 출력층이 마지막 residual 배열을 직접 읽도록 한다. 중간 층마다 최종 배열을 복사하던 동작을 없앤다. 외부 입력·상태 갱신·수치 연산은 유지하며 합성기가 실제 저장 공간을 줄이는지 검증한다.',
     method_code='data_t layer_output[H_SIZE]; // layer-local\n// Update hidden state and residual from layer_output\nLinear(... layer_in[NUM_LAYERS] ...);')}


def transform(text,mode):
    marker='void ResGRU('
    assert text.count(marker)==1
    before,body=text.split(marker,1);body=marker+body
    if mode=='pipeline':
        helper='''void Input_Projection_Stage(data_t ix, data_t qx,
    weight_t weights[H_SIZE][6], data_t bias[H_SIZE],
    weight_t slope, data_t output[H_SIZE]) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=2
#pragma HLS ARRAY_PARTITION variable=weights complete dim=0
#pragma HLS ARRAY_PARTITION variable=bias complete dim=1
#pragma HLS ARRAY_PARTITION variable=output complete dim=1
    data_t features[6];
    accum_t projected[H_SIZE];
#pragma HLS ARRAY_PARTITION variable=features complete dim=1
#pragma HLS ARRAY_PARTITION variable=projected complete dim=1
    FExLayer<data_t>(ix,qx,features);
    Linear<6,H_SIZE,data_t,weight_t,accum_t>(features,weights,bias,projected);
    nnet::prelu<accum_t,data_t,weight_t,H_SIZE>(projected,output,slope);
}

'''
        pattern=r'        FEx : FExLayer<data_t>.*?PReLU : nnet::prelu<accum_t,data_t,weight_t,H_SIZE>\(x_inj, gru_in,prelu_param\);'
        body,n=re.subn(pattern,'        Input_Projection_Stage(IQ_seq[t][0],IQ_seq[t][1],W_inj,b_inj,prelu_param,gru_in);',body,count=1,flags=re.S)
        assert n==1
        body=body.replace('    data_t x_w_fex[6];\n','').replace('    accum_t x_inj[H_SIZE];\n','')
        return before+helper+body
    assert mode=='lifetime'
    assert body.count('    data_t layer_out[NUM_LAYERS][H_SIZE];')==1
    body=body.replace('    data_t layer_out[NUM_LAYERS][H_SIZE];\n','')
    body=body.replace('    data_t gru_in[H_SIZE], gru_out[H_SIZE];','    data_t gru_in[H_SIZE];')
    line='        LAYER_LOOP: for (int l = 0; l < NUM_LAYERS; l++) {\n'
    assert line in body
    body=body.replace(line,line+'            data_t layer_output[H_SIZE];\n#pragma HLS ARRAY_PARTITION variable=layer_output complete dim=1\n')
    body=body.replace('layer_out[l]','layer_output')
    copy='            copy_row<H_SIZE>(layer_in[NUM_LAYERS],gru_out);'
    assert copy in body
    body=body.replace(copy,'')
    assert '(gru_out,W_out,b_out, OUT_seq[t])' in body
    body=body.replace('(gru_out,W_out,b_out, OUT_seq[t])','(layer_in[NUM_LAYERS],W_out,b_out, OUT_seq[t])')
    return before+body


def prepare(parent,version,mode):
    p=ROOT/'experiments'/parent;case=ROOT/'experiments'/version
    assert not case.exists() and not (ROOT/'results'/version).exists()
    for folder in ['src','tb']:shutil.copytree(p/folder,case/folder)
    for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt','tanh_expected.txt']:
        if (p/name).exists():shutil.copy2(p/name,case/name)
    f=case/'src/multi_gru.cpp';f.write_text(transform(f.read_text(encoding='utf-8'),mode),encoding='utf-8')
    f=case/'tb/tb_resgru.cpp';f.write_text(f.read_text(encoding='utf-8').replace(p.as_posix(),case.as_posix()),encoding='utf-8')
    assert (case/'src/multi_gru.h').read_bytes()==(p/'src/multi_gru.h').read_bytes()
    state=json.loads((ROOT/'results'/parent/'state.json').read_text());cfg=json.loads((p/'config.json').read_text())
    cfg.update(METHODS[mode]);cfg.update(version=version,candidate_id=version,parent='Accepted '+parent,parent_version=parent,
        experiment_date='2026-11-10',comparison_output=f'results/{parent}/evidence/csim/hls_out.txt',
        baseline_resources=state['resources'],baseline_period_ns=state['timing']['period_ns'],baseline_wns_ns=state['timing']['wns_ns'],
        parent_state_sha256=hashlib.sha256((ROOT/'results'/parent/'state.json').read_bytes()).hexdigest(),
        reference_args=['--config',(case/'multipartite.json').as_posix()],require_parent_q12_exact=True,
        check_no_added_call_stalls=False,interpretation='입력·연산 동일성과 II=2·15 ns를 먼저 확인하고 실제 LUT/FF 절감으로 판정한다. 소스 범위 축소나 함수 경계 변경 자체를 레지스터 절감 증거로 보지 않는다. 부모 대비 유효한 자원 이득이 없으면 실제 삭제한다.')
    cfg.pop('expected_scalar_fifo_depth',None)
    files=[x for folder in ['src','tb'] for x in (case/folder).iterdir() if x.is_file()]+[x for x in case.iterdir() if x.suffix=='.txt' or x.name=='multipartite.json']
    cfg['candidate_sha256']={x.relative_to(case).as_posix():hashlib.sha256(x.read_bytes()).hexdigest() for x in files}
    (case/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
    (case/'changes.diff').write_text(''.join(difflib.unified_diff((p/'src/multi_gru.cpp').read_text(encoding='utf-8').splitlines(True),(case/'src/multi_gru.cpp').read_text(encoding='utf-8').splitlines(True),fromfile=parent+'/src/multi_gru.cpp',tofile=version+'/src/multi_gru.cpp')),encoding='utf-8')
    (case/'range_audit.json').write_text(json.dumps(dict(mode=mode,top_header_byte_identical=True,arithmetic='unchanged; parent Q12 exact required',recurrent_product_helpers='unchanged',reset='unchanged'),indent=2),encoding='utf-8')
    doc=ROOT/'docs'/f'{version}_{mode}.md'
    doc.write_text(f'# {version}: '+cfg['title']+'\n\n'+cfg['method_description']+'\n\n## 논문 근거와 적용 범위\n\n'+cfg['paper_scope']+'\n\n[원문]('+cfg['paper']+')\n\n## 검증과 판정\n\n전체 7,680샘플 부모/독립 참조/C/RTL 일치, II=2, 실제 15 ns setup/hold 및 배선 오류 0, 공식 PA 조건을 유지한다. 비트폭과 반올림·포화·외부 입력은 유지한다.\n\n'+cfg['interpretation']+'\n\n[진행표](../results/batch/SUMMARY.md)\n',encoding='utf-8')
    print('PREPARED',version,mode,'parent',parent,flush=True)


def main():
    parent='v3.3'
    assert json.loads((ROOT/'results'/parent/'state.json').read_text())['disposition']=='accepted'
    for mode in ['pipeline','lifetime']:
        version='v3.'+str(int(parent.split('.')[1])+1)
        prepare(parent,version,mode)
        subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),version],cwd=ROOT.parent)
        state=json.loads((ROOT/'results'/version/'state.json').read_text())
        if state.get('disposition')=='accepted' and not state.get('error'):
            parent=version
            print('ACCEPTED',parent,mode,flush=True)
        elif state.get('disposition')=='discard_pending_delete':
            print('REJECTED',version,mode,state.get('error','Resource criteria not met'),flush=True)
            remove_failed(version)
        else:
            print('STOP unresolved tool error',version,state.get('error'),flush=True);return
    print('Both structure trials completed; latest accepted:',parent,flush=True)


if __name__=='__main__':main()
