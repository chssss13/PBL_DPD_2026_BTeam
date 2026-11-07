# C05 — 입력 GRU 누산20,5

2026-11-05. 계획 P04를 구현했다. v2 최종 채택본에서 독립 분기했으며 C03 r unsigned12와 C04 recurrent 누산19,4는 포함하지 않았다.

- 변경: `src/gru_cell.h`의 `Experiment_Input_MAC` 누산형 한 줄을21,6→20,5로 축소. 소수15비트와 AP_RND/AP_SAT는 유지한다.
- recurrent 누산21,6, 항별 곱18,3, 최종18,3 변환, 나머지 DUT와 테스트벤치는 기존 최종본과 동일하다. `source.diff`, `source_sha256.json` 참고.
- 현재 모델의 Q10 입력 가중치와 data15,3 전체 입력 범위를 사용해45개 행·225개 부분합을 검사했다. 기존 곱의 F15 반올림·포화를 포함한 최대 절댓값 상한14.70281982421875는20,5의 ±16 범위 안이다. 임의 런타임 가중치까지 보장하지 않는다. `accumulator_range_audit.json` 참고.
- 기존과 동일한 Vitis HLS2024.1 / xczu7ev-ffvc1156-2-e /15ns / uncertainty1ns / DSP full reg false 조건이다.
- C-sim7,680개와 최종본/Python 참조 Q12 일치를 확인한 뒤 csynth를 진행한다. 실패하면 합성을 실행하지 않는다. `status.txt`, `csynth.log`, `exit_code.txt`, `csim_comparison.json`으로 실제 진행 상태를 확인한다.
- C04 P&R과 병행하도록 실행했다. 이 후보의 P&R·RTL co-sim·PA 재평가는 미실시이며 이번 요청 범위는 C-sim·csynth다.

## 실행 확인

**현재 판단: csynth 완료 후보로 보관, P&R 보류.** 2026-11-05 사용자 요청에 따라 추가 구현 실행 없이 후보로 남긴다. 기각이나 최종 채택을 의미하지 않는다.

C-sim7,680개는 최종본과 최대 오차0, Python 참조와 Q12 불일치0으로 통과했다. 2026-11-05 21:05 csynth 정상 완료, 종료코드0이다. LOOP_T II2/Depth18, HLS 추정13.840ns/Fmax72.26MHz, LUT222,010/FF127,980/DSP489/BRAM0이다. 기준 대비 LUT360개(0.16%) 감소, 추정 주기0.041ns 감소, 나머지 자원·II·Depth는 동일하다. HLS top latency149/interval128클록이며 RTL co-sim 실측값과 구분한다. P&R 미실시, 채택 미정이다.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
