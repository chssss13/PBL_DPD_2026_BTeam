# C13 — C12 + 최상위 DATAFLOW 제거

부모: C12 final_recurrent_acc_nosat_csynth. 변경은 ResGRU의 DATAFLOW 한 줄 삭제다. 다른 함수의 DATAFLOW는 유지한다.
C12의 recurrent 누산21,6 AP_WRAP과 모든 나머지 자료형·수치연산·테스트벤치를 유지한다. run.tcl/run.cmd/launch.cmd도 C12와 동일하다.
15ns, uncertainty1ns, II2 요청, DSP full reg false, xczu7ev-ffvc1156-2-e, Vitis HLS2024.1.
C-sim7680개 기준 Q12 일치 후 csynth를 실행한다. P&R·co-sim은 실행하지 않는다.
비교1 C12: II2/Depth18/13.881ns/LUT221290/FF127980/DSP489/BRAM0.
비교2 C06(DATAFLOW만 제거): II3/Depth21/13.999ns/LUT138995/FF18500/DSP411/BRAM0.
II2 회복 여부와 HLS 자원을 확인한다. HLS 추정 결과는 P&R 결과와 구분한다.

## 완료 결과 (2026-11-06)
C13 csynth 정상 완료(15분34초): LOOP_T II3/Depth21, 추정13.999ns, LUT133820/FF18503/DSP411/BRAM0. C06 대비 LUT5175 감소, FF3 증가, II 동일. 중간 포화 제거로 II2 회복하지 못했다. P&R 미실시.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
