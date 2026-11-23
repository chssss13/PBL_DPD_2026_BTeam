"""Pack a FastGRNN parameter JSON into the 237-value HLS testbench image.

All coefficient fields contain sigmoid-applied values. GRU checkpoints are not
accepted or converted: the FastGRNN cell requires separately trained parameters.
Uses only the Python standard library.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

GROUPS = [
    ('W_inj', [5, 6], 14, 4, False), ('b_inj', [5], 15, 3, False),
    ('prelu', [], 14, 4, False), ('gating', [3], 14, 4, True),
    ('W', [3, 5, 5], 14, 4, False), ('U', [3, 5, 5], 14, 4, False),
    ('b_z', [3, 5], 15, 3, False), ('b_h', [3, 5], 15, 3, False),
    ('zeta', [3], 14, 4, True), ('nu', [3], 14, 4, True),
    ('W_out', [2, 5], 14, 4, False), ('b_out', [2], 15, 3, False),
]

def flatten(value, shape, name):
    if shape:
        if not isinstance(value, list) or len(value) != shape[0]:
            raise ValueError(f'{name}: expected shape {shape}')
        return [x for i, v in enumerate(value) for x in flatten(v, shape[1:], f'{name}[{i}]')]
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f'{name}: expected finite numeric scalar')
    return [float(value)]

def contract():
    offset = 0
    groups = []
    for name, shape, bits, integer, unit in GROUPS:
        count = math.prod(shape)
        groups.append(dict(name=name, shape=shape, offset=offset, count=count,
                           bits=bits, integer_bits=integer, fractional_bits=bits-integer,
                           unit_interval=unit))
        offset += count
    assert offset == 237
    return dict(top='ResFastGRNN', parameters=237, logical_parameter_bits=3355,
                order='C row-major; layer, output, input',
                coefficients='sigmoid already applied, range [0,1]', groups=groups)

def pack(data):
    expected = {g[0] for g in GROUPS}
    if not isinstance(data, dict) or set(data) != expected:
        raise ValueError(f'Expected exactly these groups: {sorted(expected)}')
    values = []
    for name, shape, bits, integer, unit in GROUPS:
        items = flatten(data[name], shape, name)
        low = -(2 ** (integer-1))
        high = -low - 2 ** -(bits-integer)
        if any(x < low or x > high or (unit and not 0 <= x <= 1) for x in items):
            raise ValueError(f'{name}: outside representable range or coefficient [0,1]')
        values.extend(items)
    assert len(values) == 237
    return ''.join(f'{x:.17g}\n' for x in values)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, help='Trained FastGRNN parameter JSON')
    parser.add_argument('--out', type=Path, required=True, help='New output file; no overwrite')
    parser.add_argument('--contract', action='store_true', help='Write interface schema instead')
    args = parser.parse_args()
    if args.contract:
        text = json.dumps(contract(), indent=2) + '\n'
    else:
        if args.input is None:
            parser.error('--input is required unless --contract is specified')
        text = pack(json.loads(args.input.read_text(encoding='utf-8')))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open('x', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print(args.out, hashlib.sha256(text.encode()).hexdigest())

if __name__ == '__main__':
    main()
