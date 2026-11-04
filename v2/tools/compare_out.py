"""HLS 출력과 참조 출력 비교 → PASS / FAIL (numpy만 필요).

    python tools/compare_out.py hls_out.txt ref.txt --nmse_max -60

- 두 파일 모두 T x 2 (I Q). 짧은 쪽 길이에 맞춰 비교합니다.
- 마지막 줄은 항상 PASS 또는 FAIL 한 단어 → regression 스크립트에서 `tail -1`로 판정.
"""
import argparse

import numpy as np


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("hls")
    ap.add_argument("ref")
    ap.add_argument("--nmse_max", type=float, default=-60.0, help="허용 NMSE 상한 (dB)")
    ap.add_argument("--bitexact", action="store_true", help="완전 일치 요구 (같은 고정소수점 형식으로 출력한 경우)")
    a = ap.parse_args()

    h = np.loadtxt(a.hls, ndmin=2)
    r = np.loadtxt(a.ref, ndmin=2)
    n = min(len(h), len(r))
    h, r = h[:n], r[:n]
    err = h - r
    nmse = 10 * np.log10(max(np.sum(err ** 2), 1e-300) / np.sum(r ** 2))
    worst = int(np.argmax(np.abs(err).max(axis=1)))
    print(f"samples      : {n}")
    print(f"NMSE         : {nmse:.2f} dB (limit {a.nmse_max} dB)")
    print(f"max |err|    : {np.abs(err).max():.3e} at t={worst}  hls={h[worst]} ref={r[worst]}")
    print(f"mismatch cnt : {int(np.sum(np.any(err != 0, axis=1)))}")
    ok = (np.all(err == 0)) if a.bitexact else (nmse <= a.nmse_max)
    print("PASS" if ok else "FAIL")


if __name__ == "__main__":
    main()
