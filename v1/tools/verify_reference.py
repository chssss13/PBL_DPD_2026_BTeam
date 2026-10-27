"""Compare completed accuracy-reference C-sim with its Python model and evaluate PA."""
from pathlib import Path
import os
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
out = root / 'results/v1.1_reference/csim_reference'
out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, PYTHONIOENCODING='utf-8')


def run(name, arguments, cwd=root):
    command = [sys.executable, *map(str, arguments)]
    result = subprocess.run(command, cwd=cwd, env=env, capture_output=True,
                            text=True, encoding='utf-8')
    (out / name).write_text(subprocess.list2cmdline(command) + '\n' + result.stdout + result.stderr,
                            encoding='utf-8')
    print(result.stdout, flush=True)
    result.check_returncode()
    return result.stdout


ref = out / 'ref_new.txt'
run('reference.log', [root / 'tools/hw_ref.py', '--golden', root / 'golden',
                      '--data_t', '16,3', '--weight_t', '16,4', '--accum_t', '32,12',
                      '--act', 'exact', '--fex', 'exact', '--reset_every', '2560', '--out', ref])
# compare_out truncates to the shorter file; enforce full length separately.
import numpy as np
hls = root / 'results/hls_out.txt'
assert np.loadtxt(hls).shape == np.loadtxt(ref).shape == (7680, 2), 'Incomplete vectors'
comparison = run('compare.txt', [root / 'tools/compare_out.py', hls, ref, '--nmse_max', '-60'])
run('evaluation.txt', [root / 'tools/eval_pa.py', '--pa',
                       'save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt',
                       root / 'golden/vectors/torch_out.txt', hls, ref], root / 'opendpd_min')
if comparison.strip().splitlines()[-1] != 'PASS':
    raise SystemExit('C/Python comparison failed; see compare.txt')
