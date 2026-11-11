"""Wait for v3.4, then run bounded lossless t-LUT alternatives sequentially."""
import argparse
import ctypes
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import hw_ref_v3

ROOT=Path(__file__).resolve().parents[1]
PAPER='https://imagelab.stu.edu.cn/upload/files/2020082318273790.pdf'


def wait_pid(pid):
    api=ctypes.WinDLL('kernel32',use_last_error=True)
    api.OpenProcess.argtypes=[ctypes.c_ulong,ctypes.c_int,ctypes.c_ulong]
    api.OpenProcess.restype=ctypes.c_void_p
    api.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_ulong]
    api.CloseHandle.argtypes=[ctypes.c_void_p]
    handle=api.OpenProcess(0x100000,False,pid)
    if handle:
        try:
            while api.WaitForSingleObject(handle,15000)==258:pass
        finally:api.CloseHandle(handle)


def prepare(parent,version,band):
    case=ROOT/'experiments'/version;p=ROOT/'experiments'/parent
    assert not case.exists() and not (ROOT/'results'/version).exists()
    for folder in ['src','tb']:shutil.copytree(p/folder,case/folder)
    for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt','candidate_directives.tcl']:
        if (p/name).exists():shutil.copy2(p/name,case/name)
    file=case/'tb/tb_resgru.cpp'
    file.write_text(file.read_text(encoding='utf-8').replace(p.as_posix(),case.as_posix()),encoding='utf-8')
    source=(p/'src/activation_interp.h').read_text(encoding='utf-8')
    packed=[int(x) for x in re.findall(r'\d+',re.search(r'tanh\[256\]\s*=\s*\{([^}]+)',source,re.S)[1])]
    assert len(packed)==256
    bases=[(v&32767)-32768 if v&16384 else v&32767 for v in packed]
    lows=[min(bases[i:i+band]) for i in range(0,256,band)]
    residuals=[v-lows[i//band] for i,v in enumerate(bases)]
    width=max(residuals).bit_length();bits=band.bit_length()-1
    assert all(lows[i//band]+residuals[i]==v for i,v in enumerate(bases))
    header='#pragma once\n#include "ap_int.h"\nnamespace tanh_twofold {\n'
    header+='static const ap_int<13> low['+str(len(lows))+']={'+','.join(map(str,lows))+'};\n'
    header+=f'static const ap_uint<{width}> residual[256]={{'+','.join(map(str,residuals))+'};\n'
    header+='static const ap_uint<8> delta[256]={'+','.join(str(v>>15) for v in packed)+'};\n}\n'
    (case/'src/tanh_twofold.h').write_text(header,encoding='utf-8')
    f=case/'src/activations.h';text='#include "tanh_twofold.h"\n'+f.read_text(encoding='utf-8')
    old='    ap_uint<23> packed = activation_interp_tables::tanh[index];'
    assert old in text
    new=f'''    #pragma HLS ARRAY_PARTITION variable=tanh_twofold::low complete dim=1
    #pragma HLS ARRAY_PARTITION variable=tanh_twofold::residual complete dim=1
    #pragma HLS ARRAY_PARTITION variable=tanh_twofold::delta complete dim=1
    ap_int<15> decoded_base=ap_int<15>(tanh_twofold::low[index >> {bits}])+ap_int<15>(tanh_twofold::residual[index]);
    ap_uint<23> packed;
    packed.range(14,0)=decoded_base.range(14,0);
    packed.range(22,15)=tanh_twofold::delta[index];'''
    f.write_text(text.replace(old,new),encoding='utf-8')
    fixture=case/'tanh_expected.txt'
    fixture.write_text('\n'.join(str(hw_ref_v3.activate(raw,packed)) for raw in range(-16384,16384))+'\n',encoding='utf-8')
    f=case/'tb/tb_resgru.cpp';text=f.read_text(encoding='utf-8')
    test='''
    std::ifstream tanh_reference("FIXTURE");
    for(int raw=-16384;raw<16384;++raw) {
        int expected; if(!(tanh_reference >> expected)) return 40;
        ap_fixed<15,3,AP_RND,AP_SAT> input,output;
        input.range(14,0)=ap_int<15>(raw);
        nnet::tanh_comb<decltype(input),decltype(output),nnet::activ_config>(input,output);
        if(output.to_double()*4096!=expected) return 41;
    }
    std::cout << "Twofold tanh full input-domain PASS" << std::endl;
'''.replace('FIXTURE',fixture.as_posix())
    f.write_text(text.replace('int main(int argc, char** argv) {','int main(int argc, char** argv) {'+test),encoding='utf-8')
    state=json.loads((ROOT/'results'/parent/'state.json').read_text())
    cfg=json.loads((p/'config.json').read_text())
    cfg.update(version=version,candidate_id=version,title=f'Lossless twofold tanh base table, band {band}',parent='Accepted '+parent,parent_version=parent,
        parent_state_sha256=hashlib.sha256((ROOT/'results'/parent/'state.json').read_bytes()).hexdigest(),
        comparison_output=f'results/{parent}/evidence/csim/hls_out.txt',baseline_resources=state['resources'],baseline_period_ns=state['timing']['period_ns'],baseline_wns_ns=state['timing']['wns_ns'],
        reference_args=['--config',(case/'multipartite.json').as_posix()],require_parent_q12_exact=True,paper=PAPER,
        paper_scope='IEEE TVLSI 28(12), 2020, DOI 10.1109/TVLSI.2020.3015391; band minimum plus positive residual storage, adapted losslessly to existing interpolation base coefficients',
        method_description=f'입력 인터페이스·연산·출력 정밀도를 유지하고 tanh 256개 base 계수를 {band}개 단위의 최솟값+양의 잔차 표로 무손실 복원한다. delta와 보간 곱셈은 유지한다.',
        method_code=f'base = low[index >> {bits}] + residual[index];',
        interpretation='표 저장 비용과 복원 덧셈을 합친 실제 PPA로 판단한다. 전체 tanh 입력 및 부모 출력과 bit-exact를 요구하며 15 ns 또는 자원 기준 미달이면 삭제한다.')
    files=[x for folder in ['src','tb'] for x in (case/folder).iterdir() if x.is_file()]+[x for x in case.iterdir() if x.suffix in ['.txt','.tcl'] or x.name=='multipartite.json']
    cfg['candidate_sha256']={x.relative_to(case).as_posix():hashlib.sha256(x.read_bytes()).hexdigest() for x in files}
    (case/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
    diff=[]
    for name in ['activations.h','tanh_twofold.h']:
        old=p/'src'/name;new=case/'src'/name
        diff.extend(difflib.unified_diff(old.read_text(encoding='utf-8').splitlines(True) if old.exists() else [],new.read_text(encoding='utf-8').splitlines(True),fromfile=parent+'/src/'+name,tofile=version+'/src/'+name))
    (case/'changes.diff').write_text(''.join(diff),encoding='utf-8')
    (case/'range_audit.json').write_text(json.dumps(dict(band=band,low_width=13,residual_width=width,coefficient_mismatches=0,full_domain_test=32768,interface='unchanged'),indent=2),encoding='utf-8')
    (ROOT/'docs'/f'{version}_twofold_tanh.md').write_text(f'# {version}: tanh 계수 무손실 twofold 표\n\n'+cfg['method_description']+'\n\n'+cfg['paper_scope']+'\n\n[논문]('+PAPER+')\n\n'+cfg['interpretation']+'\n',encoding='utf-8')
    print('Prepared',version,'parent',parent,'band',band,flush=True)


def remove_failed(version):
    commands=["$ErrorActionPreference='Stop'"]
    targets=[ROOT/'experiments'/version,ROOT/'results'/version,*list((ROOT/'docs').glob(version+'_*.md'))]
    for p in targets:
        p=p.resolve();assert p.is_relative_to(ROOT.resolve()) and not p.is_symlink()
        if p.exists():
            literal=str(p).replace("'","''")
            commands.append(f"Remove-Item -LiteralPath '{literal}'"+(' -Recurse' if p.is_dir() else ''))
    subprocess.run(['powershell','-NoProfile','-Command','\n'.join(commands)],check=True)
    from candidate_summary import render
    render()


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--wait-pid',type=int,required=True);args=ap.parse_args()
    print('Waiting for current v3.4 controller',args.wait_pid,flush=True);wait_pid(args.wait_pid)
    p=ROOT/'results/v3.4/state.json'
    status=json.loads(p.read_text()) if p.exists() else {}
    if status.get('error') or (p.exists() and status.get('disposition')!='accepted'):
        print('STOP: unresolved current flow error',flush=True);return
    parent='v3.4' if status.get('disposition')=='accepted' else 'v3.3'
    version='v3.'+str(int(parent.split('.')[1])+1)
    # Bounded alternatives: keep the first accepted one, otherwise actually delete.
    for band in [8,16]:
        prepare(parent,version,band)
        subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),version],cwd=ROOT.parent)
        state=json.loads((ROOT/'results'/version/'state.json').read_text())
        if state.get('disposition')=='accepted' and not state.get('error'):
            print('ACCEPTED',version,'bounded continuation complete',flush=True);return
        if state.get('disposition')=='discard_pending_delete':
            print('REJECTED',version,'band',band,state.get('error','Resource criteria not met'),flush=True)
            remove_failed(version)
        else:
            print('STOP: tool error; no next candidate launched',flush=True);return
    print('All queued lossless alternatives rejected and deleted; accepted parent preserved',flush=True)


if __name__=='__main__':main()
