"""Save and validate latest full-length C-sim against an experiment reference."""
import argparse
from pathlib import Path
import shutil
import subprocess
import os
import sys
import numpy as np

p = argparse.ArgumentParser()
p.add_argument('experiment', help='Directory relative to v1 with ref.txt')
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / a.experiment
out.mkdir(parents=True, exist_ok=True)
shutil.copy2(root / 'results/hls_out.txt', out / 'hls_out.txt')
shutil.copytree(root / 'src', out / 'src', dirs_exist_ok=True)
shutil.copy2(root / 'scripts/run_resgru.tcl', out / 'run_resgru.tcl')
shutil.copy2(root / 'tb/tb_resgru.cpp', out / 'tb_resgru.cpp')
ref, hls = out / 'ref.txt', out / 'hls_out.txt'
assert np.loadtxt(ref).shape == np.loadtxt(hls).shape == (7680, 2)
env = dict(os.environ, PYTHONIOENCODING='utf-8')


def run(name, arguments, cwd):
    cmd = [sys.executable, *map(str, arguments)]
    r = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, encoding='utf-8')
    (out / name).write_text(r.stdout + r.stderr, encoding='utf-8')
    print(r.stdout, flush=True)
    r.check_returncode()
    return r.stdout


comparison = run('compare.txt', [root / 'tools/compare_out.py', hls, ref, '--nmse_max', '-60'], root)
run('c_evaluation.txt', [root / 'tools/eval_pa.py', '--pa',
                        'save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt',
                        root / 'golden/vectors/torch_out.txt', hls, ref], root / 'opendpd_min')
if comparison.strip().splitlines()[-1] != 'PASS':
    raise SystemExit('C/Python mismatch')
