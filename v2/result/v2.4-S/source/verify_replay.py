"""Compare replay C-sim against the archived v2.4-S Q3.12 output."""
import sys
import numpy as np

reference, actual = (np.loadtxt(path) for path in sys.argv[1:3])
if reference.shape != (7680, 2) or actual.shape != reference.shape:
    raise SystemExit('Unexpected output shape')
if not np.isfinite(actual).all():
    raise SystemExit('Non-finite replay output')
count = int(np.count_nonzero(np.rint(reference * 4096) != np.rint(actual * 4096)))
if count:
    raise SystemExit(f'C-sim mismatch: {count} Q3.12 components')
print('PASS: replay C-sim matches 7680 archived Q3.12 outputs')
