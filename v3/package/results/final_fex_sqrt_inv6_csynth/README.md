# C18: FEx sqrt/div inverse16,6

최종 v2 기반, FEx만 교체. data15,3·weight14,4·DATAFLOW 유지. 15ns / uncertainty1ns / 목표 II2. 동일 Python 후보와 전체7680개 C-sim Q12 일치 확인 후 csynth 실행. P&R 미요청. C18/C19는 같은 부모의 병렬 대안이며 채택 미정.

상태: status.txt, csim_comparison.json, csynth.log 확인.

## HLS 완료 (2026-11-06)
C-sim 7680개 해당 Python 참조와 Q12 불일치0. LOOP_T II2 / Depth38, 추정13.924ns (71.82MHz), LUT226088 / FF128774 / DSP478 / BRAM0. 호출 지연169cycle, 호출 간격128cycle. 부모 최종 v2는13.881ns, II2/Depth18, LUT222370/FF127980/DSP489. P&R 미실시, 채택 미정.


공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
