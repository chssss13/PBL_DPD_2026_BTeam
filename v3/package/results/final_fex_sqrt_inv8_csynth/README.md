# C19: FEx sqrt/div inverse16,8

최종 v2 기반, FEx만 교체. data15,3·weight14,4·DATAFLOW 유지. 15ns / uncertainty1ns / 목표 II2. 동일 Python 후보와 전체7680개 C-sim Q12 일치 확인 후 csynth 실행. P&R 미요청. C18/C19는 같은 부모의 병렬 대안이며 채택 미정.

상태: status.txt, csim_comparison.json, csynth.log 확인.

## HLS 완료 (2026-11-06)
C-sim 7680개 해당 Python 참조와 Q12 불일치0. LOOP_T II2 / Depth38, 추정13.924ns (71.82MHz), LUT226094 / FF128774 / DSP478 / BRAM0. 호출 지연169cycle, 호출 간격128cycle. 부모 최종 v2는13.881ns, II2/Depth18, LUT222370/FF127980/DSP489. P&R 미실시, 채택 미정.


## P&R 시작 (2026-11-06)
사용자 요청으로 기존 csynth 프로젝트에서 표준 export_design -flow impl -format ip_catalog 실행. 15ns 조건 유지, Vivado 직접 remap 설정은 적용하지 않음. 완료 후 timing100에 setup100개·타이밍 요약·자원 보고서를 자동 생성. 기존 C-sim/HLS 결과 보존. 실행 로그 impl.log, 상태 impl_status.txt. 실행 시작은 타이밍 통과를 의미하지 않음.


## P&R 완료 (2026-11-06)
15ns IP 내부 조건에서 WNS+0.064457ns / WHS+0.019ns / 미배선0, 비교주기14.936ns로 통과. 최악100경로 추출 완료. routed LUT47240 / FF42738 / DSP347 / BRAM0. 최종 v2(41387/41088/362/0) 대비 LUT+5853(+14.14%), FF+1650(+4.02%), DSP−15(−4.14%). 최종 v2 WNS+0.093ns보다 여유는 소폭 감소. 외부 I/O 지연 조건은 별도이며, 채택 여부는 아직 미정. C-sim은 해당 Python 후보와 일치했으며 RTL co-sim은 미실시.


공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
