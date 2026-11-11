"""Import four pinned sehyeon methods, retaining only successful candidates."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from organize_results import evidence_path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
COMMIT = '176b59b'
METHODS = ['sigmoid_symmetry','area_high','recurrent_nosat','bias_presum']
BATCH = ROOT/'results/batch'
JOURNAL = BATCH/'sehyeon_sequence.json'


def git_file(path):
    return subprocess.check_output(['git','show',f'{COMMIT}:{path}'],cwd=REPO).decode('utf-8')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_once(text, old, new):
    assert text.count(old) == 1, old[:100]
    return text.replace(old,new,1)


def prepare(parent,version,method):
    p = ROOT/'experiments'/parent
    case = ROOT/'experiments'/version
    assert not case.exists() and not (ROOT/'results'/version).exists()
    pstate = json.loads((ROOT/'results'/parent/'state.json').read_text(encoding='utf-8'))
    assert pstate['disposition'] == 'accepted' and pstate['mandatory_conditions_pass']
    cfg = json.loads((p/'config.json').read_text(encoding='utf-8'))
    for rel,digest in cfg['candidate_sha256'].items():
        assert sha(p/rel) == digest,rel
    for folder in ['src','tb']:
        shutil.copytree(p/folder,case/folder)
    for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt','implementation_directives.tcl']:
        if (p/name).exists():
            shutil.copy2(p/name,case/name)
    tb = case/'tb/tb_resgru.cpp'
    text = tb.read_text(encoding='utf-8').replace(p.as_posix(),case.as_posix())
    # Retain the validated parent's stdio limit: this Vitis CRT supports 2048.
    tb.write_text(text,encoding='utf-8')
    methods = list(cfg.get('sehyeon_methods',[])) + [method]
    if method == 'sigmoid_symmetry':
        source = git_file('v3/result/v3.1/src/activations.h')
        pattern = r'void sigmoid_comb\(data_T data, res_T &res\) \{.*?\n\}'
        function = re.search(pattern,source,re.S)[0]
        target = case/'src/activations.h'
        old = target.read_text(encoding='utf-8')
        new,n = re.subn(pattern,lambda _:function,old,count=1,flags=re.S)
        assert n == 1
        target.write_text(new,encoding='utf-8')
        table_source = git_file('v3/result/v3.1/src/activation_interp.h')
        positive_match = re.search(r'sigmoid\[128\]\s*=\s*\{([^}]+)',table_source,re.S)
        assert positive_match
        table = case/'src/activation_interp.h'
        old = table.read_text(encoding='utf-8')
        new,n = re.subn(r'sigmoid\[256\]\s*=\s*\{[^}]+',lambda _:'sigmoid[128] = {'+positive_match[1],old,count=1,flags=re.S)
        assert n == 1
        table.write_text(new,encoding='utf-8')
        positive = [int(x) for x in re.findall(r'\d+',positive_match[1])]
        assert len(positive) == 128
        full = [((4096-(v&32767)-(v>>15))&32767)|((v>>15)<<15) for v in reversed(positive)]+positive
        expected = []
        for raw in range(-16384,16384):
            position = raw+16384
            packed = full[position>>7]
            expected.append((packed&32767)+(((packed>>15)*(position&127)+64)>>7))
        (case/'sigmoid_expected.txt').write_text('\n'.join(map(str,expected))+'\n',encoding='utf-8')
    elif method == 'area_high':
        (case/'implementation_directives.tcl').write_text('config_export -vivado_synth_design_args {-directive AreaOptimized_high}\n',encoding='utf-8')
        cfg['vivado_synth_directive'] = 'AreaOptimized_high'
    elif method == 'recurrent_nosat':
        target = case/'src/gru_cell.h'
        text = target.read_text(encoding='utf-8')
        for name in ['Recurrent_Gate_MAC','Recurrent_N_Row_MAC']:
            pattern = rf'{name}\(.*?\n\}}'
            block = re.search(pattern,text,re.S)[0]
            changed = block.replace('wide_acc_t acc = 0;', 'typedef ap_fixed<accum_T::width, accum_T::iwidth, AP_RND, AP_WRAP> product_nosat_t;\n    wide_acc_t acc = 0;')
            changed,n = re.subn(r'accum_T\((Recurrent_(?:Term|Row)_Product<[^\n]+)',r'product_nosat_t(\1',changed)
            assert n == 5
            text = replace_once(text,block,changed)
        target.write_text(text,encoding='utf-8')
    elif method == 'bias_presum':
        # Import only the exact bias presummation delta; retain our arithmetic,
        # activation functions, inverse and input interfaces.
        target = case/'src/gru_cell.h'
        text = target.read_text(encoding='utf-8')
        source = git_file('v3/result/v3.3/src/gru_cell.h')
        block = re.search(r'template<int HIDDEN_SIZE, typename data_T, typename accum_T>\nvoid Gate_Calc_Presummed_PE\(.*?\n\}',source,re.S)[0]
        anchor = 'template<int IN_SIZE, int HIDDEN_SIZE, typename data_T, typename weight_T, typename accum_T>\nvoid GRU_Cell_PE('
        text = replace_once(text,anchor,block+'\n\n'+anchor)
        target.write_text(text,encoding='utf-8')
        source = git_file('v3/result/v3.3/src/multi_gru.cpp')
        block = re.search(r'void GRU_single_presummed\(.*?\n\}',source,re.S)[0]
        target = case/'src/multi_gru.cpp'
        text = target.read_text(encoding='utf-8')
        text = replace_once(text,'void GRU_multi(',block+'\n\nvoid GRU_multi(')
        precompute = re.search(r'    // Two signed Q3.12 biases.*?(?=    LOOP_T:)',source,re.S)[0]
        text = replace_once(text,'    LOOP_T:',precompute+'    LOOP_T:')
        text = replace_once(text,'            GRU_single(','            GRU_single_presummed(')
        text = replace_once(text,'                b_in[l], b_hn[l]\n','                b_in[l], b_hn[l], b_r_sum[l], b_z_sum[l]\n')
        target.write_text(text,encoding='utf-8')
    cfg.update(version=version,candidate_id=version,title='Sehyeon incremental: '+method,parent='Accepted '+parent,parent_version=parent,
        parent_state_sha256=sha(ROOT/'results'/parent/'state.json'),experiment_date='2026-11-10',sehyeon_commit=COMMIT,sehyeon_methods=methods,
        comparison_output=evidence_path(ROOT/'results'/parent/'csim/hls_out.txt').relative_to(ROOT).as_posix(),
        baseline_resources=pstate['resources'],baseline_period_ns=pstate['timing']['period_ns'],baseline_wns_ns=pstate['timing']['wns_ns'],
        reference_script='sehyeon_sequence_reference.py',reference_args=['--config',(case/'config.json').as_posix()],
        require_parent_q12_exact=method != 'sigmoid_symmetry',force_baseline_q12_exact=False,resource_priority=True,resource_reduction_planned=True,
        method_description='Import only '+method+' from sehyeon '+COMMIT+' onto last accepted local candidate.',
        method_code={'sigmoid_symmetry':'// mirror negative segments; store 128 positive sigmoid entries',
                     'area_high':'config_export -vivado_synth_design_args {-directive AreaOptimized_high}',
                     'recurrent_nosat':'typedef ap_fixed<accum_T::width, accum_T::iwidth, AP_RND, AP_WRAP> product_nosat_t;',
                     'bias_presum':'b_r_sum[l][i] = b_ir[l][i] + b_hr[l][i]; // once per block; exact Q4.12'}[method],
        interpretation='마지막 채택본과 실제 구현 자원·타이밍·PA를 비교한다. 필수 조건 및 자원 개선 기준 미달은 폐기한다.',
        paper='Local git branch sehyeon at '+COMMIT,paper_scope='Branch technique transfer; no new literature claims')
    files = [x for folder in ['src','tb'] for x in (case/folder).iterdir() if x.is_file()]
    files += [case/name for name in ['multipartite.json','sigmoid_expected.txt','inverse_expected.txt','implementation_directives.tcl'] if (case/name).exists()]
    cfg['candidate_sha256'] = {x.relative_to(case).as_posix():sha(x) for x in files}
    (case/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
    diff = []
    for file in files:
        rel = file.relative_to(case)
        old = (p/rel).read_text(encoding='utf-8').splitlines(True) if (p/rel).exists() else []
        diff.extend(difflib.unified_diff(old,file.read_text(encoding='utf-8').splitlines(True),fromfile=parent+'/'+rel.as_posix(),tofile=version+'/'+rel.as_posix()))
    (case/'changes.diff').write_text(''.join(diff),encoding='utf-8')
    (ROOT/'docs'/f'{version}_sehyeon_incremental.md').write_text(f'# {version}: {method}\n\n부모: {parent}. 출처: sehyeon {COMMIT}. 한 가지 방식만 추가한다.\n\nII=2, 구현 15ns 및 setup/hold·배선 오류 0, 독립 정수 참조·PA·전체 C/RTL 검증을 요구한다. LUT/FF/DSP 하나 이상 1% 감소, 다른 자원 증가 1% 이하일 때만 채택한다. 미달 방식은 폐기하고 마지막 채택본에서 다음 후보를 시작한다.\n',encoding='utf-8')
    print('PREPARED',version,method,'parent',parent,flush=True)


def save(journal):
    BATCH.mkdir(parents=True,exist_ok=True)
    JOURNAL.write_text(json.dumps(journal,indent=2),encoding='utf-8')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--prepare-only',action='store_true')
    args = ap.parse_args()
    journal = json.loads(JOURNAL.read_text()) if JOURNAL.exists() else dict(source_commit=COMMIT,parent='v3.3',next_method=0,trials=[],status='running')
    assert journal['source_commit'] == COMMIT
    while journal['next_method'] < len(METHODS):
        parent = journal['parent']
        version = 'v3.'+str(int(parent.split('.')[1])+1)
        method = METHODS[journal['next_method']]
        case = ROOT/'experiments'/version
        if not case.exists():
            prepare(parent,version,method)
        else:
            current = json.loads((case/'config.json').read_text())
            assert current.get('sehyeon_methods',[])[-1:] == [method], 'Unrelated existing candidate; refusing to overwrite'
        journal.update(status='running',active_version=version,active_method=method)
        journal.pop('error',None)
        save(journal)
        if args.prepare_only:
            return
        subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),version],cwd=REPO,check=True)
        state = json.loads((ROOT/'results'/version/'state.json').read_text())
        trial = dict(version=version,method=method,parent=parent,disposition=state.get('disposition'),resources=state.get('resources'),resource_delta=state.get('resource_delta'),timing=state.get('timing'),quality=state.get('hls_out.txt'),error=state.get('error'))
        if state.get('error') and state.get('disposition') != 'discard_pending_delete':
            journal.update(status='tool_error',error=state['error'])
            save(journal)
            raise RuntimeError('Tool error; not counted as failed design: '+state['error'])
        if state.get('disposition') == 'accepted':
            journal['parent'] = version
        elif state.get('disposition') == 'discard_pending_delete':
            journal['pending_rejection'] = trial
            save(journal)
            from continue_resource_search import remove_failed
            remove_failed(version)
            assert not case.exists() and not (ROOT/'results'/version).exists()
            trial['deleted'] = True
            journal.pop('pending_rejection',None)
        else:
            raise RuntimeError('Missing final disposition; refusing next trial')
        journal['trials'].append(trial)
        journal['next_method'] += 1
        save(journal)
    journal.update(status='complete',active_version=None,active_method=None)
    save(journal)
    print('SEQUENCE COMPLETE; final accepted parent',journal['parent'],flush=True)


if __name__ == '__main__':
    main()
