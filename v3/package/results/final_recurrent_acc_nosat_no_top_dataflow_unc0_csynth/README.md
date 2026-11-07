# C14 — C13 uncertainty 0ns

부모는 C13이다. 소스·테스트벤치는 SHA256으로 모두 동일함을 확인했다.
run.tcl의 set_clock_uncertainty 1.0만0.0으로 변경했다. 목표 클록15ns, II2 요청, DSP full reg false, 부품·도구·검증 벡터는 동일하다.
C-sim7680개 Q12 기준 비교 통과 후 csynth 실행. C13과 별도 프로젝트에서 병렬 실행한다.
HLS 스케줄 여유 완화로 II2 회복 여부를 진단한다. P&R15ns 통과를 의미하지 않는다. P&R·co-sim 미실시, 채택 미정.

## 완료 결과 (2026-11-06)
C14 csynth 정상 완료(16분10초): LOOP_T II3/Depth20, 추정14.965ns(Fmax66.82MHz), LUT133874/FF19063/DSP411/BRAM0. C13 대비 LUT54/FF560 증가, Depth1 감소, 추정주기0.966ns 증가, II3 유지. uncertainty 완화로 II2 회복하지 못했다. P&R 미실시; 실제15ns 위반 여부는 미확정.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
