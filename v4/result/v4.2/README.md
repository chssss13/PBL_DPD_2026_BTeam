# v4.2 — FEx 역제곱근 결과의 BRAM 조회

[v4.1](../v4.1/README.md)의 Newton–Raphson 4회 계산을 BRAM ROM 조회로 바꿨다. ROM에는 구간별 1차식으로 미리 구한 역제곱근 결과를 입력 코드 16,384개에 대해 저장한다. 출력 FC 21/6과 기존 FIFO 깊이 2를 유지한다. [FEx 소스](fullrom_fc21/src/linear_layer.h) · [ROM 테이블](fullrom_fc21/src/fex_inverse_rom.h).

| 항목 | v4.1 | v4.2 |
|---|---:|---:|
| Python PA NMSE (dB) | −45.03 | −45.19 |
| Python PA EVM (dB) | −48.78 | −48.90 |
| Python PA ACPR 좌 / 우 (dBc) | −53.51 / −50.38 | −53.43 / −50.25 |
| P&R LUT | 37,415 | 36,810 |
| P&R FF | 38,503 | 41,015 |
| P&R DSP | 362 | 347 |
| P&R BRAM 36 Kib 타일 | 0 | 7.5 |
| P&R WNS (ns) | +0.103748 | +0.240651 |

PA 평가는 동일 7,680샘플 기준이다. P&R은 목표 주기 15 ns 기준이며, v4.1은 `AreaOptimized_high`, v4.2는 `sdx_optimization_effort_high`를 썼다. v4.2의 FIFO 저장·제어가 차지한 19,448 FF는 전체의 47.4%였다. [블록별 FF 비교](../../README.md#블록별-ff-변화).

[PA 정확도 비교](fullrom_fc21/pa_comparison.txt) · [P&R 자원](reports/rom_default/utilization.rpt) · [P&R 타이밍](reports/rom_default/timing_summary.rpt)
