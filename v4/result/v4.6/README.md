# v4.6 — GRU 1층 입력 가중치 직접 전달

[v4.5](../v4.5/README.md)에서 GRU 1층의 입력 가중치 `W_ir`, `W_iz`, `W_in` 각 25개, 총 75개가 소비 블록 내부 전달 레지스터를 거치던 경로를 바꿨다. 곱셈기가 필요한 시점에 FIFO 출력을 직접 사용하도록 HLS 생성 RTL의 연결을 수정했다.

| P&R 항목 | v4.5 | v4.6 | 변화 |
|---|---:|---:|---:|
| LUT | 21,398 | 21,660 | +262 (+1.2%) |
| FF | 21,539 | 19,171 | −2,368 (−11.0%) |
| DSP | 347 | 347 | 0 |
| BRAM 36 Kib 타일 | 7.5 | 7.5 | 0 |
| WNS (ns) | +0.059697 | +0.138466 | +0.078769 |
| 비교 주기 (ns) | 14.940303 | 14.861534 | −0.078769 |

두 구현의 Vivado 합성 옵션은 `AreaOptimized_high`다. Verilog/XSim co-sim에서 표준 7,680샘플과 호출마다 1층 가중치를 바꾸는 1,024샘플 조건을 통과했다. 표준 출력은 부모와 Q12 일치했고, 호출 지연 144클록과 호출 간격 134클록도 유지했다. 테스트한 호출 조건에서의 결과다.


[P&R 자원](reports/utilization.rpt) · [타이밍](reports/timing_summary.rpt) · [표준 co-sim](reports/standard_cosim.rpt) · [출력 대조](reports/standard_validation.json) · [가중치 변경 co-sim](reports/stress_cosim.rpt) · [75개 RTL 연결 기록](reports/rtl_changes.json)
