# C17 — 결합 비트 축소 csynth

부모는 combined_bit_candidates_csim이다. 소스와 테스트벤치 SHA256 일치 확인 후, 부모의 7,680개 C-sim 최종본·결합 Python Q12 일치 결과를 승계한다. 다시 C-sim을 실행하지 않았다.
15ns, uncertainty1ns, LOOP_T II2 요청, DSP full reg false, xczu7ev-ffvc1156-2-e. DATAFLOW 및 입출력·bias·외부 가중치 포트는 유지한다.
여러 자료형을 결합했으므로 개별 효과를 분리할 수 없다. csynth 결과는 status.txt와 csynth.log, 이후 HLS report로 확인한다. P&R·co-sim 미실시.

## HLS 완료 결과 (2026-11-06)
csynth 정상 완료(23분33초), LOOP_T II2/Depth19, 추정13.992ns, LUT277580/FF202179/DSP534/BRAM0. 기준 최종본 대비 LUT+55210, FF+74199, DSP+45, Depth+1, 추정주기+0.111ns. HLS top latency149→193클록, 추정 interval128클록 유지. 실제 호출 간격 co-sim 미실시.
주의: 단순 비트 폭 효과만 측정한 결과가 아니다. 외부 가중치 포트를 유지하기 위해 추가한 multi_gru.cpp:310~312 내부 변환 루프가 DATAFLOW 프로세스3개로 생성됐고 전체 프로세스는2→7개가 됐다. FIFO 추정 자원이 LUT40066→65660, FF59202→97020으로 증가했다. 증가분 전체를 변환 루프로 단정할 수 없으며 main LOOP_T 자원도 증가했다. 수치 검증은 통과했지만 이 구현 형태는 자원 절감에 불리하다. P&R 미실시, 채택 미정.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
