"""Validate both v1.3 C-sim outputs against v1.2 Python vectors and PA targets."""
from pathlib import Path
import os
import subprocess
import sys
import numpy as np

root = Path(__file__).resolve().parents[1]
out = root / 'results/fex_comparison/csim'
env = dict(os.environ, PYTHONIOENCODING='utf-8')


def run(name, args, cwd):
    command = [sys.executable, *map(str, args)]
    result = subprocess.run(command, cwd=cwd, env=env, capture_output=True,
                            text=True, encoding='utf-8')
    (out / name).write_text(subprocess.list2cmdline(command) + '\n' + result.stdout + result.stderr,
                            encoding='utf-8')
    print(result.stdout, flush=True)
    result.check_returncode()
    return result.stdout


vectors = [root / 'golden/vectors/torch_out.txt',
           root / 'results/v1.1_reference/csim_reference/hls_out.txt']
passed = True
for bits in (3, 8):
    hls = out / f'invI{bits}/hls_out.txt'
    ref = root / f'results/fex_comparison/python/fixed16_invI{bits}.txt'
    assert np.loadtxt(hls).shape == np.loadtxt(ref).shape == (7680, 2)
    result = run(f'compare_invI{bits}.txt', [root / 'tools/compare_out.py', hls, ref,
                                           '--nmse_max', '-60'], root)
    passed &= result.strip().splitlines()[-1] == 'PASS'
    vectors.append(hls)
run('evaluation.txt', [root / 'tools/eval_pa.py', '--pa',
                      'save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt',
                      *vectors], root / 'opendpd_min')
if not passed:
    raise SystemExit('C/Python mismatch')
