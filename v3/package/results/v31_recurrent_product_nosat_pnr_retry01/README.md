# P08 P&R 재시도 01

2026-11-07. 부모 v31_recurrent_product_nosat_csim의 csynth/RTL을 재생성 없이 복사했다. 347개 합성·RTL 파일 SHA256 일치 확인. AreaOptimized_high, 15ns 유지.

원래 실행은 IP 생성 시 Common 17-741 Tcl store 쓰기 권한 경고 후 EXCEPTION_ACCESS_VIOLATION으로 실패했다. 스택이 없어 직접 원인은 미확정이다. 실패 원본을 보존하고, 이전 성공 실행 조건처럼 샌드박스 밖에서 숨김 실행했다. 현재 결과 미확정.

로그: impl.log. 완료 후 timing100에 100경로·자원·타이밍·배선 상태 보고서를 생성한다.

2026-11-07 최종 export/P&R 정상 완료(impl_exit_code=0). ResGRU_export.rpt의 배선 후 LUT 38,047 / FF 40,960 / DSP 362 / BRAM 0. WNS +0.155487ns, WHS +0.036848ns, 미배선 0, Timing met. 비교 주기14.845ns. v3.1 N1b 대비 LUT −1,815(−4.55%), FF −208(−0.51%), DSP/BRAM 동일. 현재 추가 setup 100경로 보고서는 생성 중이며 전체 후처리 완료와 구분한다. P08 채택 미정.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
