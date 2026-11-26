# v5-5.3 · 3층 GRU 가중치 18개 고정 계수 APoT

v5-5.2의 PReLU를 유지하고 3층 W_hn 16개와 W_in 2개의 곱을 고정 시프트·덧셈으로 구현했다. W_hn 중 8개는 기존 14/4 값에 정확히 일치하고 8개는 1~3 LSB 바뀌었다. W_in 2개는 기존 값을 정확히 표현한다. 이 18개는 RTL에 고정되며 이번 변경에서 추가 재학습은 하지 않았다. [배포 가중치](weights) · [W_hn 선택 내역](selection.json) · [C-sim 및 PA 평가 수치](reports/accuracy.json)

Vivado 2024.1, xczu7ev-ffvc1156-2-e, 15 ns, AreaOptimized_high. 기존 샘플 루프 II=2 스케줄을 유지한 RTL 변경이다. 아래는 배치·배선 후 결과다.

| 버전 | LUT | FF | DSP | BRAM 타일 | WNS (ns) |
|---|---:|---:|---:|---:|---:|
| v5-5.1 | 17,349 | 12,690 | 220 | 7.5 | +0.132 |
| v5-5.2 | 16,412 | 13,067 | 220 | 7.5 | +0.246 |
| v5-5.3 | 16,441 | 12,391 | 202 | 7.5 | +0.234 |

테스트 7,680샘플의 NMSE(dB) / 좌·우 ACPR(dBc)은 −43.98 / −50.85 / −48.89이며 세 기준을 통과했다. 120회 호출에서 RTL 출력 15,360워드가 해당 가중치의 C-sim과 일치했다. 이 폴더에서 Icarus Verilog와 Python으로 `python verify.py`를 실행해 확인할 수 있다.

[RTL](rtl) · [검증 벡터](test) · [배선 자원](reports/utilization.rpt) · [배선 타이밍](reports/timing_summary.rpt)
