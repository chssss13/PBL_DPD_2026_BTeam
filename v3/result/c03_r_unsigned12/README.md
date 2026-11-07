# C03 — r unsigned12

2026-11-05. 부모는 [v2 최종 채택본](../../../v2/result/final/README.md)이며 BRAM·비균일 tanh 후보와 독립적이다. **미채택: 사용자 결정으로 기존 v2 최종본 유지.** P&R 및100경로 보고서 완료(각 종료 코드0).

`gru_cell.h`의 `r * (W_hn_h + b_hn)`에서 r만 signed15,3에서 unsigned12,0으로 표현했다. 소수부12비트, 다른 연산과 최종 반올림·포화는 유지한다. [diff](source.diff).

- sigmoid 입력 32,768개 전수: r Q12 정수값74~4,022, 표현 변경 불일치0. C++ 곱셈 경계검사6,321개 PASS. 곱셈 표현34,7→31,4로 소수부27비트 유지.
- C-sim7,680개: 최종 C-sim과 최대 오차0, Python 참조와 Q12 불일치0. [검증](csim_comparison.json).
- csynth 완료, 종료 코드0. LOOP_T II2/Depth18, 추정 주기13.881ns(Fmax72.04MHz)로 기준과 동일.

| HLS 추정 자원 | 최종본 | C03 | 차이 |
|---|---:|---:|---:|
| LUT | 222,370 | 221,755 | −615(−0.28%) |
| FF | 127,980 | 127,920 | −60(−0.05%) |
| DSP | 489 | 489 | 0 |
| BRAM_18K | 0 | 0 | 0 |

HLS에서는 소폭 LUT·FF 감소이며 DSP 수는 줄지 않았다. PA 재평가·RTL co-sim은 미실시다. 로그의 전체 loop constraint 경고와 별개로 실제 LOOP_T 보고서 II는2이며, 모든 내부 루프의 제약을 만족했다는 의미는 아니다.

## P&R 결과

같은 15ns 조건에서 setup/hold 위반0, WNS+0.052ns, WHS+0.037ns로 타이밍 통과했다.

| 항목 | v2 최종본 | C03 | 차이 |
|---|---:|---:|---:|
| LUT | 41,387 | 41,297 | −90(−0.22%) |
| FF | 41,088 | 41,156 | +68(+0.17%) |
| DSP | 362 | 362 | 0 |
| BRAM | 0 | 0 | 0 |
| WNS(ns) | +0.093 | +0.052 | −0.041 |
| 비교 주기 15−WNS(ns) | 14.907 | 14.948 | +0.041 |

타이밍은 유지했으나 여유가0.041ns 감소했다. LUT90개 감소와 FF68개 증가로 자원 이득은 작고 일방적인 개선은 아니다. 비교 주기는 실제 데이터 경로 지연과 구분한다. 결과 비교 후 사용자가 기존본 유지를 선택해 미채택으로 기록했다. 다음 후보에 이 변경을 누적하지 않는다.

[자원 보고서](pnr/utilization.rpt) · [타이밍 요약](pnr/timing_summary.rpt) · [setup100경로](pnr/setup_paths100.rpt).

P&R은 기존 csynth 소스 해시를 확인한 뒤 같은 15ns 조건으로 실행했다. 완료 후 setup 경로100개·타이밍 요약·자원 보고서를 자동 생성한다. 진행은 로컬 실행 폴더의 `impl.log`와 `impl_status.txt`를 확인한다. 초기 experiment.json의 pnr_requested=false 이후 요청이므로 해당 폴더 `pnr_run.json`에 후속 실행 조건을 기록했다.

[top 보고서](ResGRU_csynth.rpt) · [LOOP_T 보고서](Loop_LOOP_T_proc_csynth.rpt) · [설정](experiment.json) · [로컬 실행 폴더](../../package/results/final_r_unsigned12_csynth/).
