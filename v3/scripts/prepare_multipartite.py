"""Prepare v3.3 from accepted v3.2 without changing the parent."""
from pathlib import Path
import json, shutil, hashlib, re, difflib

r=Path(__file__).resolve().parents[1]
c=r/'experiments/v3.3'; p=r/'experiments/v3.2'
assert not c.exists(), 'Candidate already exists'
t=json.loads((r/'results/v3.3/reference/multipartite.json').read_text())
for folder in ['src','tb']:
    shutil.copytree(p/folder,c/folder)
(c/'multipartite.json').write_text(json.dumps(t),encoding='utf-8')
shutil.copy2(p/'inverse_expected.txt',c/'inverse_expected.txt')
h='#pragma once\n#include "ap_int.h"\nnamespace multipartite {\n'
h+='static const ap_uint<12> base[256]={'+','.join(map(str,t['base']))+'};\n'
body='''    ap_uint<15> position=data.range(14,0);
    position[14]=!position[14];
    ap_uint<8> index=position.range(14,7);
    ap_uint<16> offset=0;
#pragma HLS ARRAY_PARTITION variable=multipartite::base complete dim=1
'''
for i,a in enumerate(t['tables']):
    if not any(a['values']): continue
    h+=f'static const ap_uint<{a["width"]}> part{i}[{len(a["values"])}]={{'+','.join(map(str,a['values']))+'};\n'
    bits=a['bits']; g=a['gamma']; s=a['shift']
    body+=f'''#pragma HLS ARRAY_PARTITION variable=multipartite::part{i} complete dim=1
    ap_uint<{g+bits}> address{i}=(ap_uint<{g+bits}>(index >> {8-g}) << {bits}) | ap_uint<{g+bits}>(position.range({s+bits-1},{s}));
    offset+=multipartite::part{i}[address{i}];
'''
(c/'src/multipartite.h').write_text(h+'}\n',encoding='utf-8')
body+='    ap_uint<16> result=ap_uint<16>(multipartite::base[index])+((offset+ap_uint<16>(4)) >> 3);\n    res.range(14,0)=result.range(14,0);\n'
f=c/'src/activations.h'; text='#include "multipartite.h"\n'+f.read_text(encoding='utf-8')
text,n=re.subn(r'(void sigmoid_comb\(data_T data, res_T &res\) \{).*?\n\}',lambda m:m.group(1)+'\n#pragma HLS INLINE off\n#pragma HLS LATENCY min=0 max=0\n'+body+'}',text,count=1,flags=re.S)
assert n==1
f.write_text(text,encoding='utf-8')
fixture=c/'sigmoid_expected.txt';fixture.write_text('\n'.join(map(str,t['output']))+'\n',encoding='utf-8')
f=c/'tb/tb_resgru.cpp';text=f.read_text(encoding='utf-8').replace((p/'inverse_expected.txt').as_posix(),(c/'inverse_expected.txt').as_posix())
test='''
    std::ifstream sigmoid_reference("FIXTURE");
    for(int raw=-16384;raw<16384;++raw) {
        int expected; if(!(sigmoid_reference >> expected)) return 30;
        ap_fixed<15,3,AP_RND,AP_SAT> input,output;
        input.range(14,0)=ap_int<15>(raw);
        nnet::sigmoid_comb<decltype(input),decltype(output),nnet::activ_config>(input,output);
        if(output.to_double()*4096!=expected) return 31;
    }
    std::cout << "Multipartite full input-domain PASS" << std::endl;
'''.replace('FIXTURE',fixture.as_posix())
assert 'int main(int argc, char** argv) {' in text
text=text.replace('int main(int argc, char** argv) {','int main(int argc, char** argv) {'+test)
f.write_text(text,encoding='utf-8')
state=json.loads((r/'results/v3.2/state.json').read_text())
cfg=json.loads((p/'config.json').read_text())
cfg.update(version='v3.3',candidate_id='v3.3',title='Multipartite sigmoid table-and-add',parent='Accepted v3.2',parent_state_sha256=hashlib.sha256((r/'results/v3.2/state.json').read_bytes()).hexdigest(),reference_script='multipartite_reference.py',reference_args=['--config',(c/'multipartite.json').as_posix()],comparison_output='results/v3.2/csim/hls_out.txt',baseline_resources=state['resources'],baseline_period_ns=state['timing']['period_ns'],baseline_wns_ns=state['timing']['wns_ns'],paper='https://perso.citi-lab.fr/fdedinec/recherche/publis/2005-TC-Multipartite.pdf',paper_scope='Partial-offset table addition; conservative quantized slope grouping is our adaptation')
files=[x for folder in ['src','tb'] for x in (c/folder).glob('*') if x.is_file()]+[c/'multipartite.json',fixture,c/'inverse_expected.txt']
cfg['candidate_sha256']={x.relative_to(c).as_posix():hashlib.sha256(x.read_bytes()).hexdigest() for x in files}
(c/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
diff=[]
for folder in ['src','tb']:
    for x in (c/folder).glob('*'):
        old=p/folder/x.name
        diff.extend(difflib.unified_diff(old.read_text(encoding='utf-8').splitlines(True) if old.exists() else [],x.read_text(encoding='utf-8').splitlines(True),fromfile='v3.2/'+folder+'/'+x.name,tofile='v3.3/'+folder+'/'+x.name))
(c/'changes.diff').write_text(''.join(diff),encoding='utf-8')
(c/'range_audit.json').write_text(json.dumps({k:t[k] for k in ['alpha','beta','guard','gammas','chunks','storage_bits','max_abs_error_lsb','monotonic']},indent=2),encoding='utf-8')
print('Prepared v3.3')
