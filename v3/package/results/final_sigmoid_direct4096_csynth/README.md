# C22 sigmoid 4096항 직접 LUT

부모는 채택 v2 최종본이다. sigmoid 보간 256구간만 현서님 중간점 방식의 직접 4096항 조회로 바꾼다. Q3.13 표를 Q3.12로 AP_RND 변환해 저장하며, tanh 보간·GRU·FEx·비트폭·DATAFLOW는 유지한다. BRAM 지시문 없이 조합 LUT로 합성되도록 요청한다. 실제 BRAM 0 여부는 csynth 결과에서 확인한다.

15 ns / uncertainty 1 ns / LOOP_T II2 요청. Python PA 참조는 direct4096_components_python의 sigmoid_direct4096 결과(NMSE −45.00 dB)다. C-sim 7,680개 출력의 Q12 일치를 확인한 뒤 csynth를 실행한다. P&R 및 RTL co-sim은 별도 결과가 나올 때까지 미실시다.

## 결과

C-sim은 7,680개 출력이 해당 Python 후보와 Q12 기준으로 일치했다. csynth는 정상 완료했으며 LOOP_T II2 / Depth18, 추정 클록 주기 13.889 ns이다. 최종 v2의 동일 조건 HLS 추정치와 비교한다.

| HLS 추정 자원 | v2 최종 | C22 | 변화 |
|---|---:|---:|---:|
| LUT | 222,370 | 238,586 | +16,216 |
| FF | 127,980 | 129,269 | +1,289 |
| DSP | 489 | 561 | +72 |
| BRAM_18K | 0 | 0 | 0 |

LUT 추정치 238,586은 장치의 230,400을 초과하지만 HLS 추정이므로 배치·배선 후의 실제 사용량이나 구현 가능 여부를 확정하지 않는다. 15 ns 배치·배선 타이밍은 미확인이다. PA 수치는 C-sim 출력과 일치한 동일 입력 Python 후보의 평가 결과다. RTL co-sim 및 P&R은 미실시이며 채택 여부는 미정이다.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
