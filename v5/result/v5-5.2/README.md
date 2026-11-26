# v5-5.2 · PReLU 고정 계수 시프트·덧셈

v5-5.1의 PReLU 계수 1039/1024를 고정했다. 1039 = 1024 + 16 − 1로 계산하고 기존 곱과 동일한 위치에서 소수점을 처리한다. 가중치는 [v5-5의 59 epoch 가중치](../v5-5/weights)를 사용한다.

Vivado 2024.1, xczu7ev-ffvc1156-2-e, 15 ns, AreaOptimized_high. 기존 샘플 루프 II=2 스케줄을 유지한 RTL 변경이다. 아래는 배치·배선 후 결과다.

| 버전 | LUT | FF | DSP | BRAM 타일 | WNS (ns) |
|---|---:|---:|---:|---:|---:|
| v5-5.1 | 17,349 | 12,690 | 220 | 7.5 | +0.132 |
| v5-5.2 | 16,412 | 13,067 | 220 | 7.5 | +0.246 |

테스트 7,680샘플의 NMSE(dB) / 좌·우 ACPR(dBc)은 −43.89 / −50.91 / −48.91이며 세 기준을 통과했다. 120회 호출에서 RTL 출력 15,360워드가 해당 가중치의 C-sim과 일치했다. 이 폴더에서 Icarus Verilog와 Python으로 `python verify.py`를 실행해 확인할 수 있다.

[RTL](rtl) · [검증 벡터](test) · [배선 자원](reports/utilization.rpt) · [배선 타이밍](reports/timing_summary.rpt)
