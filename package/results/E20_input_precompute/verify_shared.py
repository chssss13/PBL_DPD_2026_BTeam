"""Validate frozen E20 sources and archived/new Q14 outputs; stdlib only."""
from pathlib import Path
import hashlib
import json
import sys

OUT = Path(__file__).resolve().parent


def codes(path):
    rows = [line.split() for line in path.read_text().splitlines() if line.strip()]
    if not all(len(row) == 2 for row in rows):
        raise ValueError(f"Expected two I/Q columns: {path}")
    return [tuple(round(float(v) * 16384) for v in row) for row in rows]


def main():
    hashes = json.loads((OUT / "source_hashes.json").read_text(encoding="utf-8-sig"))
    for name, expected in hashes.items():
        actual = hashlib.sha256((OUT / "src_snapshot" / name).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f"Source hash mismatch: {name}")
    reference = codes(OUT / "precomputed.txt")
    rtl = codes(OUT / "rtl_out.txt")
    if len(reference) != 7680 or len(rtl) != 2624 or rtl != reference[:2624]:
        raise ValueError("Archived RTL / C-sim Q14 code mismatch or sample count mismatch")
    if len(sys.argv) > 1:
        candidate = codes(Path(sys.argv[1]))
        if len(candidate) not in (2624, 7680) or candidate != reference[:len(candidate)]:
            raise ValueError("New output differs from archived E20 Q14 codes")
        print(f"New output PASS: {len(candidate)} samples")
    print(f"PASS: {len(hashes)} source hashes, 7680 C-sim samples, 2624 RTL samples")


if __name__ == "__main__":
    main()
