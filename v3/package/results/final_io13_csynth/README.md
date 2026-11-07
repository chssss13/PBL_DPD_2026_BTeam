# C11 — 외부 I/Q 입출력만13,1

부모는 v2 최종 채택본. C06 DATAFLOW 제거, C10 함수 경계 변경, C09 remap은 포함하지 않는다.
외부 IQ_seq/OUT_seq와 테스트벤치 버퍼를 io_t13,1 AP_RND/AP_SAT로 분리했다. 입력은 FEx에 전달할 때 기존 data_t로 변환한다.
출력층 MAC·bias 계산은 기존 data_t15,3을 그대로 사용하고 마지막 출력 포트에서만13,1로 변환한다. r/n/h/bias 등 내부 자료형은 그대로다.
Python7680벡터 결과가 기존과 Q12 동일함을 앞서 확인했다. C-sim도 최종본·Python IO13과 모두 일치해야 csynth를 진행한다.
15ns, uncertainty1ns, II2 요청, DSP full reg false. P&R·co-sim 미실시.
기준 HLS LUT222370/FF127980/DSP489/BRAM0, II2/Depth18,13.881ns.
입출력 범위가[-1,4095/4096]를 벗어나면 기존15,3과 값이 달라질 수 있다. 검증 입력의 일치를 임의 입력 동등성으로 보지 않는다.

## C-sim 및 csynth 결과

2026-11-06 정상 완료, 종료코드 0. C-sim 7,680개 출력이 기존 최종본과 정확히 일치하고 Python 13,1 참조와 Q12 불일치 0이다. PA 정확도의 독립적인 재평가 결과는 Python 실험을 참조한다.

| HLS 항목 | 기존 v2 최종본 | C11 | 변화 |
|---|---:|---:|---:|
| LOOP_T II / Depth | 2 / 18 | 2 / 18 | 동일 |
| 추정 주기 | 13.881ns | 13.881ns | 동일 |
| LUT | 222,370 | 222,652 | +282 |
| FF | 127,980 | 127,948 | −32 |
| DSP | 489 | 499 | +10 |
| BRAM_18K | 0 | 0 | 동일 |
| top latency / interval | 149 / 128 | 149 / 128 | 동일 |

HLS 추정 자원은 DSP 10개와 LUT 282개가 증가했다. 증가 원인을 포화 변환으로 확정할 근거는 없다. P&R 및 RTL co-sim 미실시, 사용자 채택 판단 미정이다. HLS 추정치와 기존 P&R 실측을 직접 비교하지 않는다.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
