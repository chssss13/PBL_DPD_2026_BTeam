# C15: clock 16ns diagnostic

Parent C14; identical source/TB (SHA256 verified). Clock 16ns, uncertainty1ns, II2 request, DSP full reg false.
C-sim not rerun: inherited C14 7680-sample Q12 match; see validation_provenance.json.
Independent project, csynth only; no P&R. Diagnose achievable II under relaxed clock, not compliance with original15ns requirement.

## 완료 결과 (2026-11-06)
csynth 정상 완료: LOOP_T II3 / Depth20, 추정 주기14.965ns, LUT133874 / FF19063 / DSP411 / BRAM0. 경과16분35초. C13(15ns, uncertainty1ns)의 II3과 동일하며 추정 주기는0.966ns 늘었다. C14(15ns, uncertainty0ns)와 요약 수치는 동일하다. 18ns 후보는 별도 실행. P&R 미실시.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
