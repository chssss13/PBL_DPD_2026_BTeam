"""Portable package/output verification; Python standard library only."""
from pathlib import Path
from decimal import Decimal, ROUND_HALF_EVEN
import argparse
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]


def check_package():
    entries = json.loads((ROOT / 'SHA256SUMS.json').read_text(encoding='utf-8'))
    for rel, expected in entries.items():
        file = (ROOT / rel).resolve()
        if ROOT.resolve() not in file.parents:
            raise ValueError(f'Invalid manifest path: {rel}')
        if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != expected:
            raise ValueError(f'Package file missing or changed: {rel}')
    print(f'PASS: {len(entries)} packaged files verified')


def read_output(path):
    rows = []
    for number, line in enumerate(Path(path).read_text(encoding='utf-8').splitlines(), 1):
        if not line.strip():
            continue
        cols = line.split()
        if len(cols) != 2:
            raise ValueError(f'{path}:{number}: expected two columns')
        pair = tuple(Decimal(v) for v in cols)
        if not all(v.is_finite() for v in pair):
            raise ValueError(f'{path}:{number}: nonfinite value')
        rows.append(pair)
    if len(rows) != 7680:
        raise ValueError(f'{path}: expected 7680 rows, got {len(rows)}')
    return rows


def q12(value):
    return int((value * 4096).to_integral_value(rounding=ROUND_HALF_EVEN))


def compare(actual_path, json_path=None):
    actual = read_output(actual_path)
    comparisons = {}
    for key, name in [('python', 'python_expected.txt'), ('original_csim', 'csim_expected.txt')]:
        expected = read_output(ROOT / 'reference' / name)
        errors = [abs(a-b) for ra, rb in zip(actual, expected) for a, b in zip(ra, rb)]
        mismatches = sum(q12(a) != q12(b) for ra, rb in zip(actual, expected) for a, b in zip(ra, rb))
        comparisons[key] = {'mismatched_q12_components': mismatches, 'max_abs_error': float(max(errors))}
    result = {'samples': 7680, 'comparisons': comparisons,
              'passed': all(v['mismatched_q12_components'] == 0 for v in comparisons.values())}
    if json_path:
        Path(json_path).write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(result, indent=2))
    if not result['passed']:
        raise ValueError('C-sim mismatch; do not proceed to synthesis')


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--package', action='store_true')
    ap.add_argument('--output', type=Path)
    ap.add_argument('--json', type=Path)
    args = ap.parse_args()
    if not args.package and not args.output:
        ap.error('Use --package and/or --output FILE')
    if args.package:
        check_package()
    if args.output:
        compare(args.output, args.json)
