# C06 — 최상위 DATAFLOW 제거

2026-11-05. 사용자 요청으로 N2만 C-sim·csynth 실행한다. N1 Vivado 논리 재매핑 P&R은 보류한다.

- 부모: v2 최종 채택본 `v2/result/final`. C04/C05의 누산 폭 변경은 포함하지 않는다.
- 변경: `src/multi_gru.cpp`의 `ResGRU()` 안 `#pragma HLS DATAFLOW` 한 줄 제거. 다른 함수의 DATAFLOW, LOOP_T PIPELINE, Tcl II2 요청, 모든 수치 연산과 자료형은 유지한다. `source.diff` 참고.
- 원본과 변경 파일 외 DUT·TB의 해시 일치를 준비 스크립트에서 확인했다. `source_sha256.json`, `experiment.json` 보존.
- 조건: xczu7ev-ffvc1156-2-e, Vitis HLS2024.1,15ns, uncertainty1ns, DSP full reg false.
- C-sim7,680개 결과가 최종 C-sim 및 Python Q12 참조와 일치해야 csynth로 진행한다. `csim_comparison.json`, `status.txt`, `csynth.log`, `exit_code.txt`로 결과를 확인한다.
- 이번 범위는 C-sim·csynth까지. P&R·RTL co-sim은 실행하지 않는다. 향후 실제 처리율 비교에는 LOOP_T II뿐 아니라 기준 RTL co-sim64샘플 호출 간격134클록도 확인해야 한다.
- 기준 HLS: LUT222,370/FF127,980/DSP489/BRAM0, II2/Depth18,13.881ns. 채널 제거 예상량을 실제 자원 절감으로 간주하지 않는다.

## 시작 확인

C-sim7,680개는 최종본과 최대 오차0, Python 참조와 Q12 불일치0으로 통과했다. 2026-11-05 21:45 csynth 정상 완료, 종료코드0이다.

## HLS 결과

| 항목 | 기준 최종본 | C06 |
|---|---:|---:|
| LUT | 222,370 | 138,995 |
| FF | 127,980 | 18,500 |
| DSP | 489 | 411 |
| BRAM | 0 | 0 |
| LOOP_T II / Depth | 2 / 18 | 3 / 21 |
| 추정 주기 | 13.881ns | 13.999ns |
| HLS top latency / interval | 149 / 128 | 216 / 217 |

LUT83,375개(37.49%), FF109,480개(85.54%), DSP78개(15.95%)가 감소했으나 LOOP_T II가3으로 늘어 처리율 목표를 유지하지 못했다. 15ns의 loop 기준 이상적 처리율은33.33→22.22MSps다. top interval217클록/64샘플은 HLS 추정이며 기존 co-sim134클록과 측정 단계를 섞지 않는다. FIFO 항목이 없어지고 process 구조도 변경됐지만 절감분 전체를 FIFO 제거의 단독 기여로 단정하지 않는다. P&R·RTL co-sim 미실시, 최종 채택 판단 미정이다.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
