"""Continue the authorized v3.1 search: delete rejected candidate, reuse ID.

Deletion uses native PowerShell Remove-Item without Force, the exact operation
that succeeded for the explicitly authorized v3.1 paths. No archival fallback.
"""
import argparse
import ctypes
from ctypes import wintypes
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
CASE=ROOT/'experiments/v3.1'
OUT=ROOT/'results/v3.1'
DOC=ROOT/'docs/v3.1_fex_mixed_precision.md'


def wait_pid(pid):
    api=ctypes.WinDLL('kernel32',use_last_error=True)
    api.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD]
    api.OpenProcess.restype=wintypes.HANDLE
    api.WaitForSingleObject.argtypes=[wintypes.HANDLE,wintypes.DWORD]
    api.CloseHandle.argtypes=[wintypes.HANDLE]
    handle=api.OpenProcess(0x100000,False,pid)
    if not handle:return
    try:
        while api.WaitForSingleObject(handle,0)==258:time.sleep(15)
    finally:api.CloseHandle(handle)


def delete_rejected():
    # Only these three literal, reviewed targets may be removed.
    targets=[CASE,OUT,DOC]
    for p in targets:
        assert ROOT.resolve() in p.resolve().parents
        assert not p.is_symlink()
    commands=["$ErrorActionPreference='Stop'"]
    for p in targets:
        quoted=str(p.resolve()).replace("'","''")
        if p.exists():commands.append(f"Remove-Item -LiteralPath '{quoted}'"+(' -Recurse' if p.is_dir() else ''))
    subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-Command','\n'.join(commands)],check=True)
    assert not any(p.exists() for p in targets),'Deletion incomplete; stopping without archival fallback'


def prepare(width,integer):
    assert not CASE.exists() and not OUT.exists()
    for folder in ['src','tb']:shutil.copytree(ROOT/folder,CASE/folder)
    p=CASE/'src/linear_layer.h';s=p.read_text(encoding='utf-8')
    old='ap_fixed<16,6,AP_RND,AP_SAT> inverse_t';assert s.count(old)==1
    p.write_text(s.replace(old,f'ap_fixed<{width},{integer},AP_RND,AP_SAT> inverse_t'),encoding='utf-8')
    p=CASE/'tb/tb_resgru.cpp';s=p.read_text(encoding='utf-8').replace('#include <cstdlib>','#include <cstdlib>\n#include <cstdio>')
    s=s.replace('int main(int argc, char** argv) {','int main(int argc, char** argv) {\n#ifdef _WIN32\n    if (_setmaxstdio(2048)<0) return 10;\n#endif')
    p.write_text(s,encoding='utf-8')
    cfg=dict(version='v3.1',candidate_id='v3.1',title=f'FEx inverse mixed precision 16/6 to {width}/{integer}',parent='Preserved original v3; no discarded changes inherited',parent_commit='a1998bd42440256687f262e53eea879257515f4a',clock_ns=15,uncertainty_ns=1,target_ii=2,samples=7680,reset_every=2560,inverse_width=width,inverse_integer=integer,baseline_resources=dict(LUT=41387,FF=41088,DSP=362,BRAM_18K=0),baseline_period_ns=14.907,baseline_wns_ns=.093,force_baseline_q12_exact=False,reference_nmse_max_db=-60,min_resource_improvement_fraction=.01,paper='https://arxiv.org/abs/2404.15364',paper_scope='Mixed precision principle; no claim of QAT or paper replication')
    cfg['candidate_sha256']={p.relative_to(CASE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for f in ['src','tb'] for p in (CASE/f).glob('*') if p.is_file()}
    (CASE/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
    diff=[]
    for f in ['src','tb']:
        for p in (CASE/f).glob('*'):
            original=ROOT/f/p.name
            diff.extend(difflib.unified_diff(original.read_text(encoding='utf-8').splitlines(True),p.read_text(encoding='utf-8').splitlines(True),fromfile='baseline/'+f+'/'+p.name,tofile='v3.1/'+f+'/'+p.name))
    (CASE/'changes.diff').write_text(''.join(diff),encoding='utf-8')
    DOC.write_text(f'# v3.1 — FEx inverse {width}/{integer}\n\n[MP-DPD paper](https://arxiv.org/abs/2404.15364): mixed-precision principle applied independently, not a paper/QAT replication.\n\nOnly inverse_t changes from 16/6 to {width}/{integer}; NR seed and four iterations remain. Independent integer reference uses the same format.\n\nMandatory: II=2, routed 15ns, PA thresholds, full C/reference/RTL checks.\n\nRejected attempts are deleted; this ID is reused. See [live results](../results/batch/SUMMARY.md).\n',encoding='utf-8')


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--wait-pid',type=int,required=True);args=ap.parse_args()
    wait_pid(args.wait_pid)
    remaining=[]  # Superseded by paper-first candidate selection; not scheduled.
    for next_format in remaining+[None]:
        state=json.loads((OUT/'state.json').read_text(encoding='utf-8'))
        disposition=state.get('disposition')
        if disposition=='accepted':
            print('ACCEPTED v3.1; stopped search with verified candidate retained.',flush=True);return
        if disposition!='discard_pending_delete':
            print('STOP: tool/verification issue requires inspection, not a silent discard.',flush=True);return
        cfg=state['settings']
        print('REJECT',cfg['title'],'-- deleting candidate sources/results/document now.',flush=True)
        delete_rejected()
        print('DELETED; no backup created.',flush=True)
        if next_format is None:
            from candidate_summary import render
            render()
            print('All queued FEx formats screened; no candidate retained.',flush=True);return
        prepare(*next_format)
        print('START fresh v3.1',next_format,flush=True)
        subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),'v3.1'],cwd=ROOT.parent,check=True)


if __name__=='__main__':main()
