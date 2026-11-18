# v2 — v1에서 15 ns를 통과하기까지

이 문서는 sehyeon v1에서 시작해 v2.4-S를 거쳐 v2 최종으로 이어진 구현을 정리한다. 기존 변경 이력의 9~15번이 이 구간에 해당한다.

| 단계 | 적용한 변경 | 결과 |
|---|---|---|
| v1 → v2.4-S | ① sigmoid·tanh의 4,096칸 직접 LUT를 256구간 선형 보간으로 바꾸고, data를 16/3→15/3, weight를 16/4→14/4로 줄임. ② recurrent 곱셈을 r·z·n 게이트별로 분리 | PA NMSE와 FPGA 자원이 개선됐다. 배선 후 비교 주기는 17.506→17.524 ns로 거의 같았다. |
| v2.4-S → v2 최종 | ③ GRU 누산 폭을 21/6으로 확대. ④ recurrent 곱셈을 입력 항별로 추가 분리. ⑤ n 게이트의 recurrent 곱셈을 출력 행별로 추가 분리. ⑥ 상태 갱신용 z를 unsigned 12/0으로 변환. ⑦ 상태 갱신 결과의 최종 포화를 제거하고 반올림은 유지 | 동일 벡터에서 Q12 출력을 유지하면서 배선 후 비교 주기를 17.524→14.907 ns로 줄여 15 ns를 통과했다. |

비트폭은 전체 비트 수/정수부 비트 수 순서다.

| 지표 | sehyeon v1 | v2.4-S | v2 최종 |
|---|---:|---:|---:|
| PA NMSE (dB) | −43.57 | −44.97 | −44.97¹ |
| PA ACPR 좌 / 우 (dBc) | −51.26 / −48.02 | −53.35 / −50.08 | −53.35 / −50.08¹ |
| P&R LUT | 60,349 | 47,575 | 41,387 |
| P&R FF | 48,240 | 41,799 | 41,088 |
| P&R DSP | 584 | 333 | 362 |
| P&R BRAM | 0 | 0 | 0 |
| P&R WNS (ns) | −2.506 | −2.524 | +0.093 |
| P&R 비교 주기 (ns) | 17.506 | 17.524 | **14.907** |
| HLS 샘플 루프 II | 2 | 2 | 2 |

¹ v2 최종은 같은 7,680샘플에서 Q12 출력이 일치해 v2.4-S PA 결과를 이어 적었다. 비교 주기는 `15 ns − WNS`다.

- [sehyeon v1 측정 결과](https://github.com/chssss13/PBL_DPD_2026_BTeam/blob/d2e722658631957c278a8910b0666f243bd99cd1/result/07_lut_lookup/02_implementation/README.md)
- v2.4-S [배치·배선 자원](result/v2.4-S/reports/implementation/utilization.rpt) · [타이밍](result/v2.4-S/reports/implementation/timing_summary.rpt)
- v2 최종 [소스·재현 안내](result/final/README.md) · [단계별 코드 변경](result/final/changes/코드변경.md)
