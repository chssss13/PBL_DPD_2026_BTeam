# C12 — recurrent 중간 누산 포화 제거

부모는 v2 최종 채택본이다. P09 단독 실험이며 DATAFLOW는 유지한다.
`src/gru_cell.h`의 Recurrent_Gate_MAC(r/z)과 Recurrent_N_Row_MAC(n)의 wide_acc_t에서 AP_SAT만 AP_WRAP으로 변경했다.
폭21,6과 AP_RND는 유지한다. 입력 MAC, 곱셈 직후18,3 포화, 마지막18,3 포화는 유지한다.
18,3 항 다섯 개의 모든 부분합은 [-20,20) 안이고21,6 범위[-32,32) 안이므로 중간 오버플로가 없다. LEN=5 static_assert 조건이다.
C-sim 7,680개 출력이 최종본 및 Python 참조와 Q12 기준으로 일치했다. PA 재평가·co-sim·P&R은 미실시.
기준 HLS: II2, Depth18,13.881ns,LUT222370/FF127980/DSP489/BRAM0.
DATAFLOW 제거와 결합하지 않았다. 이번 결과만으로 제거 후 II2 회복을 판단하지 않는다.

## 완료 결과

csynth 정상 완료: LOOP_T II=2, Depth=18, 추정 주기 13.881ns, LUT 221,290 / FF 127,980 / DSP 489 / BRAM 0. 기준 대비 HLS 추정 LUT 1,080개 감소, 나머지 수치는 동일하다. P&R 결과는 없으며 채택 여부는 미정이다.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
