"""Integer reference for individually imported sehyeon methods."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
import hw_ref_v3 as network
import multipartite_reference
import seed_reference


def calculate(config_path):
    case = config_path.parent
    cfg = json.loads(config_path.read_text(encoding='utf-8'))
    methods = cfg['sehyeon_methods']
    original_dot, original_table, original_activate, original_fex = network.dot, network.table, network.activate, network.fex
    if 'recurrent_nosat' in methods:
        def dot(x, row, mode):
            if mode != 'recurrent':
                return original_dot(x, row, mode)
            acc = 0
            for a, b in zip(x, row):
                product = network.quant(int(a)*int(b), 22, 18, 3, wrap=True)
                acc = network.quant(acc+product, 15, 21, 6)
            return network.quant(acc, 15, 18, 3)
        network.dot = dot
    if 'sigmoid_symmetry' in methods:
        def table(path, name, size):
            if name != 'sigmoid':
                return original_table(path, name, size)
            positive = original_table(case/'src/activation_interp.h', name, 128)
            negative = []
            for packed in reversed(positive):
                base, delta = packed & 32767, packed >> 15
                negative.append(((4096-base-delta) & 32767) | (delta << 15))
            return negative+positive
        network.table = table
    else:
        activation = json.loads((case/'multipartite.json').read_text(encoding='utf-8'))
        def activate(raw, entries):
            return original_activate(raw, entries) if entries[0] & 16384 else activation['output'][raw+16384]
        network.activate = activate
    correction = seed_reference.correction_table(6)
    network.fex = lambda i,q,integer,width: seed_reference.feature(i,q,integer,width,steps=1,bits=6,table=correction)
    # Bias presummation is exact Q4.12; the integer reference already adds biases exactly.
    try:
        return network.calculate(5,16)
    finally:
        network.dot, network.table, network.activate, network.fex = original_dot, original_table, original_activate, original_fex


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--config', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--check', type=Path)
    args = ap.parse_args()
    actual = calculate(args.config)
    assert actual.shape == (7680,2) and np.isfinite(actual).all()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    np.savetxt(args.out, actual, fmt='%.12f')
    meta = dict(samples=len(actual),reference_source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope='Independent integer model; candidate outputs used only for comparison')
    if args.check:
        expected = np.loadtxt(args.check)
        assert expected.shape == actual.shape
        meta['q12_mismatches'] = int(np.count_nonzero(np.rint(actual*4096) != np.rint(expected*4096)))
        meta['max_abs_error'] = float(np.max(np.abs(actual-expected)))
    args.out.with_suffix('.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
    print(json.dumps(meta,indent=2))
    if meta.get('q12_mismatches',0):
        raise SystemExit(1)
