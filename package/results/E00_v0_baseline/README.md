# E00 — v0 기준선 결과

v0 원본 HLS 설계를 학습 가중치로 실행해 얻은 기준선 결과다. 이후 실험은 이 폴더의 정확도·PPA 수치와 비교한다.

## 기능 검증

| 항목 | 결과 |
|---|---:|
| HLS C-sim 샘플 | 7,680 |
| C-sim ↔ v0 Python 참조 NMSE | -82.66 dB |
| 기능 기준 (`--nmse_max -60`) | PASS |

`hls_out.txt`는 HLS C-sim 출력이며, `ref_exact.txt`와 `ref_v0.txt`는 각각 float/exact 및 v0 고정소수점 참조 출력이다. `compare_csim_vs_ref_v0.txt`에 비교 로그가 있다.

## PA 대리모델 정확도

| 출력 | NMSE | EVM | ACPR L / R |
|---|---:|---:|---:|
| Golden PyTorch | -45.52 dB | -49.42 dB | -53.59 / -50.43 dBc |
| v0 HLS C-sim | -26.67 dB | -28.10 dB | -39.48 / -36.09 dBc |

실행 환경: `C:\\work\\venv`, `eval_pa.py`; 원본 로그는 `eval_pa_v0.txt`.

## HLS 합성·구현 리포트

| 항목 | 결과 |
|---|---:|
| Target | `xczu7ev-ffvc1156-2-e`, 15 ns |
| LUT / FF / DSP / BRAM | 46,646 / 49,546 / 648 / 0 |
| Post-route period | 17.129 ns (15 ns 목표 미달) |
| C-synthesis latency / interval | 157 cycles / 128 cycles |

원본 리포트: `ResGRU_csynth.rpt`, `export_impl.rpt`.

## 재현

패키지 루트에서 `vitis_hls -f scripts/run_resgru.tcl`을 실행하고, `tools/hw_ref.py`, `tools/compare_out.py`, `tools/eval_pa.py`를 사용한다. 정확한 명령은 상위 `README.md`의 “처음 30분: v0를 직접 돌려 보기”를 따른다.
