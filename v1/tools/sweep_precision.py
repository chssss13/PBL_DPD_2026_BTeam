"""Reproduce an isolated 16-bit precision sweep; does not modify HLS sources."""
import argparse
import csv
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--out', default='results/v1.1_reference/python_sweep')
    parser.add_argument('--evaluate-only', action='store_true', help='Reuse existing output vectors')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    out = (root / args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, PYTHONIOENCODING='utf-8')
    # First isolate data and weight range with a generous accumulator.
    cases = [(d, w, '32,12') for d in (3, 4, 5) for w in (3, 4, 5)]
    # Include the original format and narrower accumulator candidates.
    cases += [(2, 2, '18,3'), (4, 4, '24,8'), (4, 4, '24,10')]
    outputs = []
    with (out / 'cases.csv').open('w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['case', 'data_t', 'weight_t', 'accum_t'])
        for d, w, acc in cases:
            name = f'd16i{d}_w16i{w}_a{acc.replace(",", "i")}'
            writer.writerow([name, f'16,{d}', f'16,{w}', acc])
            f.flush()
            target = out / (name + '.txt')
            if args.evaluate_only:
                if not target.is_file():
                    raise FileNotFoundError(target)
                outputs.append(str(target))
                continue
            command = [sys.executable, str(root / 'tools/hw_ref.py'),
                       '--golden', str(root / 'golden'), '--act', 'exact',
                       '--fex', 'exact', '--reset_every', '2560',
                       '--data_t', f'16,{d}', '--weight_t', f'16,{w}',
                       '--accum_t', acc, '--out', str(target)]
            print(f'START {name}', flush=True)
            start = time.monotonic()
            result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, encoding='utf-8')
            (out / (name + '.log')).write_text(subprocess.list2cmdline(command) + '\n' + result.stdout + result.stderr, encoding='utf-8')
            result.check_returncode()
            outputs.append(str(target))
            print(f'DONE {name}: {time.monotonic()-start:.1f}s', flush=True)
    command = [sys.executable, str(root / 'tools/eval_pa.py'), '--pa',
               'save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt',
               str(root / 'golden/vectors/torch_out.txt'), *outputs]
    result = subprocess.run(command, cwd=root / 'opendpd_min', env=env, capture_output=True, text=True, encoding='utf-8')
    (out / 'evaluation.txt').write_text(subprocess.list2cmdline(command) + '\n' + result.stdout + result.stderr, encoding='utf-8')
    print(result.stdout, flush=True)
    print(result.stderr, flush=True)
    result.check_returncode()


if __name__ == '__main__':
    main()
