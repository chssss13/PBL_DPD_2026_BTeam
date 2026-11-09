"""Delete failed seed candidates and continue bounded paper-parameter search."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
from continue_v31 import wait_pid
from candidate_summary import render

ROOT=Path(__file__).resolve().parents[1]
CASE=ROOT/'experiments/v3.2'
OUT=ROOT/'results/v3.2'
DOC=ROOT/'docs/v3.2_corrected_seed.md'


def remove_candidate():
    targets=[CASE,OUT,DOC,ROOT/'results/batch/v3.2_flow.log',ROOT/'results/batch/v3.2_error.log']
    commands=["$ErrorActionPreference='Stop'"]
    for p in targets:
        assert ROOT.resolve() in p.resolve().parents and not p.is_symlink()
        if p.exists():
            quoted=str(p.resolve()).replace("'","''")
            commands.append(f"Remove-Item -LiteralPath '{quoted}'"+(' -Recurse' if p.is_dir() else ''))
    subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-Command','\n'.join(commands)],check=True)
    assert not any(p.exists() for p in targets)


def run_next(bits,steps):
    subprocess.run([sys.executable,str(ROOT/'scripts/prepare_seed_candidate.py'),'--seed-bits',str(bits),'--steps',str(steps)],cwd=ROOT.parent,check=True)
    with (ROOT/'results/batch/v3.2_flow.log').open('w',encoding='utf-8') as output, (ROOT/'results/batch/v3.2_error.log').open('w',encoding='utf-8') as error:
        subprocess.run([sys.executable,str(ROOT/'scripts/run_flow.py'),'v3.2'],cwd=ROOT.parent,stdout=output,stderr=error,check=True)


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--wait-pid',type=int,required=True);args=ap.parse_args()
    wait_pid(args.wait_pid)
    for variant in [(5,1),(6,2),None]:
        state=json.loads((OUT/'state.json').read_text(encoding='utf-8'))
        if state.get('disposition')=='accepted':
            print('Accepted resource-reduction candidate retained; v3.1 preserved.',flush=True);break
        if state.get('disposition')!='discard_pending_delete':
            print('Tool/verification error requires inspection; no silent discard.',flush=True);break
        print('Reject:',state['settings']['title'],'-- removing actual candidate files.',flush=True)
        remove_candidate();render()
        print('Deleted, no archive.',flush=True)
        if variant is None:
            print('Bounded seed search exhausted.',flush=True);break
        print('Next v3.2 seed bits/NR steps:',variant,flush=True)
        run_next(*variant)
