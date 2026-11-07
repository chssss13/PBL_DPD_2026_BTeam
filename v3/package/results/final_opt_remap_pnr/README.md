# C09 / N1 — 최종 v2 RTL 논리 재매핑

사용자 요청으로 보류를 해제하고 별도 폴더에서 Vivado RTL 합성부터 P&R까지 실행한다.
부모는 v2 최종 채택본이며 C06/C07/C08 DATAFLOW 변경은 포함하지 않는다.
기존 packaged IP를 그대로 복사하고 run_vivado.tcl의 impl_props에
`STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreWithRemap`만 지정한다.
전체 구현 전략은 변경하지 않는다. RTL·15ns·기존 합성 directive·place/phys_opt/route 설정은 유지한다.
기존 결과는 보존한다. csynth·C-sim 재실행은 하지 않으며 기존 RTL 검증 결과를 참조한다.

기준 P&R: WNS +0.093ns, LUT41,387 / FF41,088 / DSP362 / BRAM0.
완료 후 timing100에 setup100경로·타이밍 요약·자원 보고서를 추출한다.
실행 상태: impl_status.txt, impl.log, impl_exit_code.txt, report_exit_code.txt.


초기 실행은 packaged IP의 HDL 133개(파일 목록의 중복 참조 포함 266건) 누락으로 RTL 합성 전에 실패했다. Vivado 종료코드만 사용한 COMPLETE 표시는 잘못된 것으로 정정했다. retry01은 같은 기준본 impl/syn RTL에서 누락 파일을 복구하고 component.xml 전체 파일 존재를 검증했다. Tcl catch 및 routed DCP/보고서 존재를 완료 조건에 추가했다. 복구 파일 해시는 restored_files.json에 보존한다.
