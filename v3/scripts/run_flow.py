"""Run only a candidate, sequentially; no baseline HLS reproduction."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from candidate_summary import render

ROOT=Path(__file__).resolve().parents[1]


def main():
    ap=argparse.ArgumentParser();ap.add_argument('version',choices=['v3.1','v3.2']);args=ap.parse_args()
    env=os.environ.copy();env.update(PYTHONIOENCODING='utf-8',EXPERIMENT_MIN_FREE_COMMIT_MB='8192')
    out=ROOT/'results'/args.version;out.mkdir(parents=True,exist_ok=True)
    for stage in ['csim','csynth','cosim','impl']:
        print('START',args.version,stage,flush=True)
        with (out/f'flow_{stage}.log').open('w',encoding='utf-8') as log:
            command=[sys.executable,str(ROOT/'scripts/run_candidate.py'),args.version,'--resume','--stop-after',stage]
            process=subprocess.Popen(command,cwd=ROOT.parent,env=env,stdout=log,stderr=subprocess.STDOUT)
            while process.poll() is None:
                render();time.sleep(15)
        render()
        if process.returncode:
            print('STOP: stage failed; inspect tool/design error before further work.',flush=True);return
        s=json.loads((out/'state.json').read_text(encoding='utf-8'))
        if stage=='csim' and not s['hls_out.txt']['eligible_for_synthesis']:
            s['disposition']='discard_pending_delete'
            (out/'state.json').write_text(json.dumps(s,indent=2),encoding='utf-8')
            render();print('DISCARD: C/reference/PA screening failed. Candidate artifacts require deletion.',flush=True);return
        print('FINISHED',args.version,stage,flush=True)
    print('Final disposition:',s.get('disposition'),flush=True)
    if s.get('disposition')=='discard_pending_delete':
        print('Candidate is rejected. Remove its sources/results/document via reviewed filesystem action; do not archive.',flush=True)


if __name__=='__main__':
    main()
