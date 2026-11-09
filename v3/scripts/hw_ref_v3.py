"""Independent integer reference for the preserved original v3 baseline.

No HLS output is used in the calculation. Products retain exact Python integer
precision until the C++ assignment/explicit conversion points are modeled.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT


def quant(raw, frac, width, integer, wrap=False):
    raw = int(raw)
    shift = frac - (width - integer)
    result = (raw + (1 << (shift - 1))) >> shift if shift > 0 else raw << -shift
    if wrap:
        return ((result + (1 << (width-1))) % (1 << width)) - (1 << (width-1))
    return min(max(result, -(1 << (width-1))), (1 << (width-1))-1)


def plus(a, b):
    f = max(a[1], b[1])
    return ((a[0] << (f-a[1])) + (b[0] << (f-b[1])), f)


def times(a, b):
    return (int(a[0])*int(b[0]), a[1]+b[1])


def fex(i, q, inverse_integer, inverse_width=16):
    amp2 = quant(i*i+q*q, 24, 15, 3)
    delta = (amp2-4096, 12)
    initial = plus(plus((1, 0), times((-1, 1), delta)), times((3, 3), times(delta, delta)))
    inv = quant(*initial, inverse_width, inverse_integer)
    inv_frac = inverse_width-inverse_integer
    for _ in range(4):
        sq = times((inv, inv_frac), (inv, inv_frac))
        correction = plus((3, 1), times((-1, 1), times((amp2, 12), sq)))
        inv = quant(*times((inv, inv_frac), correction), inverse_width, inverse_integer)
    amp = quant(amp2*inv, 12+inv_frac, 15, 3)
    return [i, q, amp, quant(amp*amp2, 24, 15, 3),
            quant(q*inv, 12+inv_frac, 15, 3), quant(i*inv, 12+inv_frac, 15, 3)]


def table(path, name, size):
    text = path.read_text(encoding='utf-8')
    match = re.search(r'\b'+name+r'\['+str(size)+r'\]\s*=\s*\{([^}]+)', text, re.S)
    assert match, name
    values = [int(v) for v in re.findall(r'\d+', match[1])]
    assert len(values) == size
    return values


def activate(raw, entries):
    pos = raw+16384
    packed = entries[pos >> 7]
    base = packed & 32767
    if base >= 16384:
        base -= 32768
    return base + (((packed >> 15)*(pos & 127)+64) >> 7)


def dot(x, row, mode):
    # Injection/output MACs clamp each addition. GRU MACs use the existing
    # Q6.15 wide accumulator and clamp only its final conversion to Q3.15.
    acc = 0
    for a, b in zip(x, row):
        if mode == 'output':
            product = quant(int(a)*int(b), 22, 15, 3)
            acc = quant(acc+product, 12, 15, 3)
        else:
            product = quant(int(a)*int(b), 22, 18, 3, wrap=False)
            acc += product
            acc = quant(acc, 15, 18, 3) if mode == 'injection' else quant(acc, 15, 21, 6)
    return acc if mode == 'output' else quant(acc, 15, 18, 3)


def calculate(inverse_integer, inverse_width=16):
    shapes = {'W_inj': (5, 6), 'b_inj': (5,), 'prelu': (1,), 'gating': (3,),
              'W_out': (2, 5), 'b_out': (2,)}
    for layer in range(3):
        for gate in ['r', 'z', 'n']:
            for path in ['i', 'h']:
                shapes[f'L{layer}_W_{path}{gate}'] = (5, 5)
                shapes[f'L{layer}_b_{path}{gate}'] = (5,)
    weights = {}
    for name, shape in shapes.items():
        values = np.loadtxt(BASE/'golden/weights'/f'{name}.txt', ndmin=1).reshape(shape)
        width, integer = (15, 3) if name.startswith('b_') or '_b_' in name else (14, 4)
        codes = np.floor(values*(1 << (width-integer))+.5)
        weights[name] = np.clip(codes, -(1 << (width-1)), (1 << (width-1))-1).astype(np.int64)
    inputs = np.loadtxt(BASE/'golden/vectors/dpd_in.txt')[:7680]
    inputs = np.clip(np.floor(inputs*4096+.5), -16384, 16383).astype(np.int64)
    sig = table(BASE/'src/activation_interp.h', 'sigmoid', 256)
    tanh = table(BASE/'src/activation_interp.h', 'tanh', 256)
    hidden = [[0]*5 for _ in range(3)]
    outputs = []
    for step, pair in enumerate(inputs):
        if step % 2560 == 0:
            hidden = [[0]*5 for _ in range(3)]
        features = fex(int(pair[0]), int(pair[1]), inverse_integer, inverse_width)
        inj = [quant(dot(features, row, 'injection')+(int(bias) << 3), 15, 18, 3)
               for row, bias in zip(weights['W_inj'], weights['b_inj'])]
        prelu = int(weights['prelu'].flat[0])
        x = [quant(v, 15, 15, 3) if v > 0 else quant(v*prelu, 25, 15, 3) for v in inj]
        for layer in range(3):
            prefix = f'L{layer}_'
            gates = {}
            for gate in ['r', 'z', 'n']:
                gates['i'+gate] = [dot(x, row, 'input') for row in weights[prefix+'W_i'+gate]]
                gates['h'+gate] = [dot(hidden[layer], row, 'recurrent') for row in weights[prefix+'W_h'+gate]]
            nxt = []
            for n in range(5):
                br = int(weights[prefix+'b_ir'][n])+int(weights[prefix+'b_hr'][n])
                bz = int(weights[prefix+'b_iz'][n])+int(weights[prefix+'b_hz'][n])
                rpre = quant(gates['ir'][n]+gates['hr'][n]+(br << 3), 15, 15, 3)
                zpre = quant(gates['iz'][n]+gates['hz'][n]+(bz << 3), 15, 15, 3)
                r, z = activate(rpre, sig), activate(zpre, sig)
                rh = quant(r*(gates['hn'][n]+(int(weights[prefix+'b_hn'][n]) << 3)), 27, 15, 3)
                npre = quant(gates['in'][n]+(int(weights[prefix+'b_in'][n]) << 3)+(rh << 3), 15, 15, 3)
                candidate = activate(npre, tanh)
                nxt.append(quant((candidate << 12)+z*(hidden[layer][n]-candidate), 24, 15, 3, wrap=True))
            hidden[layer] = nxt
            gain = int(weights['gating'][layer])
            x = [quant((h << 10)+gain*v, 22, 15, 3) for h, v in zip(nxt, x)]
        outputs.append([quant(dot(x, row, 'output')+int(bias), 12, 15, 3)
                        for row, bias in zip(weights['W_out'], weights['b_out'])])
    return np.asarray(outputs, dtype=np.int64)/4096


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--inverse-integer', type=int, choices=[4,5,6], default=6)
    parser.add_argument('--inverse-width', type=int, choices=[16,17], default=16)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--check', type=Path)
    args = parser.parse_args()
    actual = calculate(args.inverse_integer,args.inverse_width)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    np.savetxt(args.out, actual, fmt='%.12f')
    result = {'samples': len(actual), 'inverse_format': [args.inverse_width, args.inverse_integer],
              'reference_source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'scope': 'Independent Python integer model; no HLS output used in calculation'}
    if args.check:
        expected = np.loadtxt(args.check)
        result['q12_mismatches'] = int(np.count_nonzero(np.rint(actual*4096) != np.rint(expected*4096)))
        result['max_abs_error'] = float(np.max(np.abs(actual-expected)))
    args.out.with_suffix('.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, indent=2))
    if args.check and result['q12_mismatches']:
        raise SystemExit(1)
