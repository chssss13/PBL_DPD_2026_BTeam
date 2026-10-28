# LUT 4096 후보의 스케줄 설정 실험: HLS II=3

**한 줄 요약:** HLS 스케줄 설정을 변경해 II를 7에서 3으로 줄였다.

- 날짜: 2026-10-29. Vitis HLS 2024.1, xczu7ev-ffvc1156-2-e, 목표 클록 15 ns.
- 계산: 직전 정확도 통과 후보와 동일한 C++ 소스. data 16,3 / weight 16,4 / accum 18,3 / LUT 4096 반올림 / FEx inverse 16,6·Newton-Raphson 4회 / 2560샘플 reset.
- 변경한 스케줄 설정: DSP_FULL_REG=false, clock uncertainty 4.05 → 1 ns, Tcl로 LOOP_T II=2 요청. 세 설정을 함께 바꿨다.
- csynth 정상 종료, 약 10분 45초. HLS achieved II=3, loop depth 19. 목표 II=2 미달.
- 주의: Tcl 로그에는 II=2 directive 실행이 기록되지만, Loop_LOOP_T_proc_csynth.rpt의 target 칸은 1로 표시된다. 이 불일치의 원인은 아직 확인하지 않았다. achieved 3과 구분한다.

| 항목 | 직전 기본 스케줄 | 설정 변경 후 |
|---|---:|---:|
| LOOP_T II | 7 | 3 |
| HLS LUT | 179,429 | 199,976 |
| FF | 132,816 | 145,178 |
| DSP | 279 | 917 |
| BRAM_18K | 60 | 160 |
| HLS 추정 클록 | 10.933 ns | 13.961 ns |
| clock uncertainty | 4.05 ns | 1.00 ns |

수치는 HLS 추정치이며 P&R 이후 결과가 아니다. 설정을 함께 변경해 각 설정의 단독 기여는 분리할 수 없다.

스케줄 변경 전 C-sim은 PA NMSE -43.57 dB, ACPR L/R -51.26 / -48.02 dBc로 통과했다. 이번 설정 이후 RTL co-sim과 PA 재평가는 하지 않았으며 실제 타이밍도 미확인이다.

- ResGRU_csynth.rpt/xml: 전체 자원·타이밍 추정.
- Loop_LOOP_T_proc_csynth.rpt/xml: loop II·지연 및 target.
- logs/csynth.log: 전체 합성 로그.
- source/: 설정 Tcl과 이전 C-sim 후보에 사용한 파일과 일치함을 확인한 C++ 소스·테스트벤치.
- 직전 C-sim과 기본 스케줄 결과: ../04_lut4096/README.md.
