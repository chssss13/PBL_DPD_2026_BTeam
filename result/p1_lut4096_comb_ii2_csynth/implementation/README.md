# II=2 후보: Vivado 배치·배선 결과

2026-10-29. C-sim과 Verilog RTL co-sim을 확인한 기존 HLS 합성 프로젝트에서 `export_design -flow impl -format ip_catalog`를 실행했다. Vivado 2024.1, FPGA `xczu7ev-ffvc1156-2-e`, 목표 주기 15 ns. HLS 합성은 clock uncertainty 1 ns, DSP full reg false, LOOP_T II=2 요청을 사용했다. Vivado 합성·구현 전략과 사용된 옵션은 `report/export_impl.rpt`에 기록되어 있다. 구현 소스는 [상위 합성 결과](../README.md)의 `source/`와 같다.

| 항목 | 결과 |
|---|---:|
| HLS LOOP_T II | 2 |
| RTL co-sim | 7,680샘플 Verilog PASS |
| RTL 출력 PA NMSE / ACPR L / ACPR R | -43.57 / -51.26 / -48.02 dB (dBc) |
| 구현 목표 주기 | 15.000 ns |
| Vivado 합성 후 주기 | 14.162 ns |
| 배선 후 주기 | 17.506 ns |
| 배선 후 WNS / TNS | -2.506 ns / -1704.159 ns |
| 타이밍 위반 종료점 | 1,239개 |
| 배선 후 WHS | +0.037 ns |
| 배선 후 LUT / FF / DSP | 60,349 / 48,240 / 584 |
| BRAM / URAM / SRL | 0 / 0 / 5,272 |

배치·배선은 정상 종료됐고 보고서상 배선 오류가 있는 net은 0개다. 자원은 FPGA 가용량에 들어가지만 **15 ns 타이밍은 통과하지 못했다.** HLS II=2와 co-sim PASS만으로 15 ns 처리 목표를 달성했다고 볼 수 없다. SRL은 LUT와 별도로 더하지 않는다. 시간은 약 51분 30초였다.

이 결과는 독립 RTL의 out-of-context 구현이다. 타이밍 리포트에는 입력 및 출력 딜레이가 지정되지 않은 포트가 표시된다. 시스템에 통합할 때 I/O 제약과 최종 타이밍을 별도로 검토해야 한다. 보드 실측은 하지 않았다.

- 전체 요약: `report/export_impl.rpt`
- 배선 후 타이밍과 주요 경로: `report/ResGRU_timing_routed.rpt`, `report/ResGRU_timing_paths_routed.rpt`
- 배선 후 자원과 배선 상태: `report/ResGRU_utilization_routed.rpt`, `report/ResGRU_status_routed.rpt`
- HLS/Vivado 전체 로그: `logs/impl.log`
- 사용된 스크립트: `impl_existing.tcl`. 이 스크립트는 실험 당시 `scripts/`에서 실행했다.
