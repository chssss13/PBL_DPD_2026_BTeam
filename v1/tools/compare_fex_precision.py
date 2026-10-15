"""Isolate FEx intermediate quantization from the double-math reference.

Nonlinear operators are ideal correctly-rounded operators, not a tested RTL
implementation. Exact activations followed by data_t rounding can be represented
by a lookup table over the finite input domain; approximation error is excluded.
"""
from pathlib import Path
import os
import subprocess
import sys
import numpy as np
import hw_ref

root = Path(__file__).resolve().parents[1]
out = root / 'results/E03_internal_precision'
out.mkdir(parents=True, exist_ok=True)
qd = hw_ref.make_q('16,3')
w, cfg = hw_ref.load_weights(root / 'golden/weights')
x = np.loadtxt(root / 'golden/vectors/dpd_in.txt')
original_fex = hw_ref.fex
files = []
for integer_bits in (3, 8):
    qi = hw_ref.make_q(f'16,{integer_bits}')

    def fixed_fex(i, q, mode):
        # Products assigned to a 16-bit variable before summation.
        i2, q2 = qd(i * i), qd(q * q)
        a2 = qd(i2 + q2)
        amp = qd(np.sqrt(a2))
        inv = qi(1.0 / amp) if amp > 0 else 0.0
        amp_sq = qd(amp * amp)
        amp3 = qd(amp_sq * amp)
        return np.array([i, q, amp, amp3, qd(q * inv), qd(i * inv)])

    hw_ref.fex = fixed_fex
    name = f'fixed16_invI{integer_bits}'
    print(f'START {name}', flush=True)
    y = hw_ref.run_fxp(w, cfg, x, qd, hw_ref.make_q('16,4'),
                      hw_ref.make_q('32,12'), 'exact', 'exact', 2560)
    target = out / (name + '.txt')
    np.savetxt(target, y, fmt='%.10f')
    files.append(target)
hw_ref.fex = original_fex
baseline = root / 'results/E02_csim_reference/ref_new.txt'
command = [sys.executable, str(root / 'tools/eval_pa.py'), '--pa',
           'save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt',
           str(root / 'golden/vectors/torch_out.txt'), str(baseline), *map(str, files)]
result = subprocess.run(command, cwd=root / 'opendpd_min',
                        env=dict(os.environ, PYTHONIOENCODING='utf-8'),
                        capture_output=True, text=True, encoding='utf-8')
(out / 'evaluation.txt').write_text(result.stdout + result.stderr, encoding='utf-8')
print(result.stdout, flush=True)
result.check_returncode()
