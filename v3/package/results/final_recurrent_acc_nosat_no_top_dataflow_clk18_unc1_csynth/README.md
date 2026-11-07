# C16: clock 18ns diagnostic

Parent C14; identical source/TB (SHA256 verified). Clock 18ns, uncertainty1ns, II2 request, DSP full reg false.
C-sim not rerun: inherited C14 7680-sample Q12 match; see validation_provenance.json.
Independent project, csynth only; no P&R. Diagnose achievable II under relaxed clock, not compliance with original15ns requirement.

## HLS 완료 및 P&R 실행 (2026-11-06)
csynth 정상 완료: LOOP_T II2 / Depth17, 추정16.939ns (59.03MHz), LUT150370 / FF18603 / DSP486 / BRAM0, 경과34분08초. 목표18ns, uncertainty1ns. 부모 C14의 C-sim7680개 Q12 일치를 승계했다.
사용자 요청으로 이 후보 HLS 프로젝트의 RTL을 이용해 18ns 제약 P&R 및 최악 setup 경로100개 보고서를 별도 실행한다. 15ns 목표와 다른 제약이므로 비교 시 주의. P&R 결과 미확정.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
