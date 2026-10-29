"""v1.4 LUT activation / v1.3 fixed intermediate FEx reference and evaluation."""
from pathlib import Path
import os
import subprocess
import sys
import numpy as np
import hw_ref

root = Path(__file__).resolve().parents[1]
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('--experiment', default='results/v1.4_lut')
parser.add_argument('--act', default='lut', choices=['lut', 'lut_direct'])
parser.add_argument('--lut-shift', type=int, choices=[2,3,4], default=4)
args = parser.parse_args()
hw_ref.DIRECT_LUT_SCALE = 8192.0 / (1 << args.lut_shift)
out = root / args.experiment
out.mkdir(parents=True, exist_ok=True)
qd, qi = hw_ref.make_q('16,3'), hw_ref.make_q('16,8')


def fex(i, q, mode):
    a2 = qd(qd(i*i) + qd(q*q))
    amp = qd(np.sqrt(a2))
    inv = qi(1/amp) if amp > 0 else 0.0
    return np.array([i, q, amp, qd(qd(amp*amp)*amp), qd(q*inv), qd(i*inv)])


hw_ref.fex = fex
w, cfg = hw_ref.load_weights(root / 'golden/weights')
x = np.loadtxt(root / 'golden/vectors/dpd_in.txt')
y = hw_ref.run_fxp(w, cfg, x, qd, hw_ref.make_q('16,4'), hw_ref.make_q('32,12'),
                   args.act, 'exact', 2560)
ref = out / 'ref.txt'
np.savetxt(ref, y, fmt='%.10f')
env = dict(os.environ, PYTHONIOENCODING='utf-8')
cmd = [sys.executable, str(root / 'tools/eval_pa.py'), '--pa',
       'save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt',
       str(root / 'golden/vectors/torch_out.txt'), str(ref)]
result = subprocess.run(cmd, cwd=root / 'opendpd_min', env=env, capture_output=True,
                        text=True, encoding='utf-8')
(out / 'python_evaluation.txt').write_text(result.stdout + result.stderr, encoding='utf-8')
print(result.stdout, flush=True)
result.check_returncode()
