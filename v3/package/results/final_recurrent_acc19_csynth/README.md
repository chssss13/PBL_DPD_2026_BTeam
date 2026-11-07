# C04 — recurrent 누산19,4

2026-11-05. v2 최종 채택본에서 독립 분기했다. 미채택 C03 r unsigned12는 포함하지 않았다.

- 변경은 `src/gru_cell.h`의 `Recurrent_Gate_MAC`, `Recurrent_N_Row_MAC` 누산형 두 줄이다.21,6→19,4로 소수15비트와 AP_RND/AP_SAT를 유지했다. `source.diff` 참고.
- 입력 MAC 누산21,6, 항별 곱18,3, 최종18,3 변환, r15,3, z unsigned12, 상태 nosat, 곱셈 분리 구조,256/256 보간은 유지했다. 테스트벤치도 기존 최종본과 동일하다.
- 현재 모델의 양자화 recurrent 가중치와 h∈[−4093,4093]/4096를 사용해45개 행의225개 부분합 범위를 계산했다. 기존 곱의 F15 반올림·포화를 반영한 최대 절댓값 상한은5.541839599609375로19,4의 ±8 안이다. 임의 런타임 가중치까지 보장하지 않는다. `accumulator_range_audit.json` 참고.
- 별도 `prj`에서 C-sim7,680개를 실행하고 최종 C-sim/Python 참조와 Q12 일치하면 csynth로 진행한다. 실패 시 합성을 실행하지 않는다. 진행은 `status.txt`, `csynth.log`, 종료는 `exit_code.txt`에서 확인한다.
- Vitis HLS2024.1, xczu7ev-ffvc1156-2-e,15ns, uncertainty1ns, DSP full reg false, LOOP_T II2 요청.
- 최초 실행은 C-sim·csynth까지였다. 이후 P&R 요청과 실행 상태는 아래 후속 기록을 따른다. RTL co-sim·PA 재평가는 미실시다.

## 실행 확인

C-sim 완료, 오류0개. 7,680개 출력은 최종 C-sim과 최대 오차0, Python 참조와 Q12 불일치0개다(`csim_comparison.json`).

2026-11-05 csynth 정상 완료(`exit_code.txt` 0). LOOP_T II=2, Depth=18, 추정 주기13.881ns, Fmax72.04MHz로 기준과 동일하다. HLS 추정 LUT225,475 / FF127,980 / DSP489 / BRAM0이며, 기준 대비 LUT만3,105개(+1.40%) 증가했다. HLS 기준 자원 감소는 확인되지 않았다. P&R은 미실시이며 채택 여부는 미정이다. 로그의 II=1 의존성 경고와 최종 II=2 결과를 구분한다.

## 후속 P&R

2026-11-05 20:18 KST 사용자 요청으로 다른 Vivado/Vitis 실행이 없음을 확인한 후 P&R을 시작했다. 기존 csynth 결과를 사용하며 다른 후보와 채택본은 유지한다. `impl.log`, `impl_status.txt`에서 진행 상태를 확인한다. 구현 성공 시 `timing100/`에 타이밍 요약·최악 setup 경로100개·자원 보고서를 자동 생성한다. 완료와 타이밍 통과 여부는 아직 미확정이다. `pnr_run.json` 참고.

## 판단 — 미채택

후속 확인에서 `project.runs/impl_1/bd_0_wrapper_timing_summary_routed.rpt`의 WNS−0.423ns, 비교 주기15.423ns, setup 위반249개, hold 위반0개를 확인했다. 사용자 요청에 따라 미채택, 기존 v2 최종본을 유지한다.

최초 판단 당시 Fully Placed 수치는 LUT44,598 / FF41,219였다. 이후 구현 및100경로 보고서 생성이 종료코드0으로 완료됐다. **최종 routed 자원은 LUT44,599 / FF41,239 / DSP362 / BRAM0**이다. 기존 최종본 대비 LUT+3,212 / FF+151 / DSP·BRAM 동일이며 미채택 판단은 유지한다. `timing100/utilization.rpt`, `decision.json` 참고.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
