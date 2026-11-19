"""Screen exact two-table encodings of the archived tanh_comb output."""
import re
from pathlib import Path


SOURCE = (Path(__file__).resolve().parents[1]
          / 'v4/result/v4.2/fullrom_fc21/src/activation_interp.h')


def main():
    table = re.search(r'tanh\[256\]\s*=\s*\{([^}]+)\}', SOURCE.read_text())
    packed = list(map(int, re.findall(r'\d+', table[1])))
    assert len(packed) == 256
    reference = []
    for raw in range(1 << 15):
        index, fraction = divmod(raw ^ (1 << 14), 128)
        word = packed[index]
        base = word & 0x7fff
        delta = (word >> 15) & 0xff
        reference.append((base + (((delta * fraction + 64) & 0x7fff) >> 7)) & 0x7fff)

    print('fine bits | unique correction rows | logical table bits')
    for fine_bits in range(1, 10):
        size = 1 << fine_bits
        bases, row_ids, corrections = [], [], {}
        for start in range(0, len(reference), size):
            base = reference[start]
            row = tuple((value - base) & 0x7fff for value in reference[start:start + size])
            row_ids.append(corrections.setdefault(row, len(corrections)))
            bases.append(base)
        rows = tuple(corrections)
        assert all(((bases[i // size] + rows[row_ids[i // size]][i % size]) & 0x7fff) == value
                   for i, value in enumerate(reference))
        selector_width = (len(rows) - 1).bit_length()
        correction_width = max(map(max, rows)).bit_length()
        cost = len(bases) * (15 + selector_width) + len(rows) * size * correction_width
        print(f'{fine_bits:9} | {len(rows):22} | {cost:18}')
    print('32768 inputs verified per split; current packed table: 5888 logical bits')


if __name__ == '__main__':
    main()
