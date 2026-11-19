# v2 — v1에서 15 ns를 통과하기까지

이 폴더에는 sehyeon이 진행한 v2.1~v2.3 초기 탐색과, 기준 코드를 바꿔 진행한 v2.4-S~v2 최종을 함께 보관한다. 초기 탐색의 출발 코드는 현서 v1.7이며, v2.4-S는 sehyeon v1에서 별도로 분기했다. 현서 브랜치의 BRAM ROM v2.1·균형 MAC v2.2와는 다른 실험이다.

## 프로젝트 진행과 v2 내부 이력

프로젝트의 큰 흐름은 **현서 v1.7 → main v2 → v3 → v4**다. 이 문서에서 현서 v1.7을 프로젝트 v1 최종으로 사용하며, 아래 sehyeon v1은 v2.4-S에서 선택한 별도 코드 기준을 뜻한다.

```text
현서 v1.7 → sehyeon의 v2.1 → v2.2 → v2.3 (초기 탐색)
sehyeon v1 → 보간·비트 축소 → v2.4-S → v2 최종 (최종 채택 계보)
```

v2.4-S에는 초기 탐색의 256구간 보간·비트 축소 아이디어를 다시 적용하고 recurrent 게이트 분리를 추가했다. v2.3의 adder tree·recurrent 중간 16/4 양자화·FEx 구현을 모두 누적한 버전은 아니다.

| 버전 | 변경 | PA NMSE (dB) | P&R LUT / FF / DSP | 비교 주기 (ns) |
|---|---|---:|---|---:|
| [v2.1](result/v2.1/README.md) | 누산기 32/12→18/3, 상태식 정리, GRU adder tree | −43.66 | 70,412 / 48,482 / 636 | 21.287 |
| [v2.2](result/v2.2/README.md) | sigmoid·tanh 512구간 선형 보간 | −45.48 | 58,319 / 48,897 / 564 | 18.649 |
| [v2.3](result/v2.3/README.md) | data 15/3·weight 14/4, 보간 256구간·recurrent 중간 16/4 양자화 | −45.11 | 56,671 / 43,367 / 305 | 18.105 |

세 버전 모두 HLS II=2·PA 기준을 만족했지만 15 ns 타이밍은 실패했다. RTL co-sim은 미실시다. 각 폴더에 당시 소스·TB·정확도 출력·로그·HLS/P&R 보고서·SHA256 목록을 보관한다. [전체 결과 목록과 재현 의존성](result/README.md)을 참고한다.

## v2.4-S에서 최종본까지

아래는 sehyeon v1에서 시작한 최종 채택 계보의 비교다. 기존 변경 이력의 9~15번이 이 구간에 해당한다.

| 단계 | 적용한 변경 | 결과 |
|---|---|---|
| sehyeon v1 기준 → v2.4-S | ① sigmoid·tanh의 4,096칸 직접 LUT를 256구간 선형 보간으로 바꾸고, data를 16/3→15/3, weight를 16/4→14/4로 줄임. ② recurrent 곱셈을 r·z·n 게이트별로 분리 | PA NMSE와 FPGA 자원이 개선됐다. 배선 후 비교 주기는 17.506→17.524 ns로 거의 같았다. |
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

## 현서 v1 최종본 → main v2.1 비교

현서 v1.7에서 주요 누산기 32/12→18/3, 상태식 `(1-z)*n+z*h_prev`→`n+z*(h_prev-n)`, GRU 입력·recurrent 행렬곱 6곳의 5항 adder tree를 적용했다. data 16/3·weight 16/4, direct LUT, FEx inverse 16/8과 내부 double sqrt·역수는 유지했다. 입력·출력 FC의 순차 누산도 유지했다.

| 지표 | 현서 v1.7 | main v2.1 | 변화 |
|---|---:|---:|---:|
| LUT | 66,859 | 70,412 | +3,553 |
| FF | 49,754 | 48,482 | −1,272 |
| DSP | 711 | 636 | −75 |
| 비교 주기(ns) | 24.054 | 21.287 | −2.767 |
| PA NMSE(dB) | −43.67 | −43.66 | +0.01 |
| ACPR L/R(dBc) | −51.82/−48.38 | −51.92/−48.52 | −0.10/−0.14 |
| HLS II | 2 | 2 | 동일 |
| 15 ns setup | 실패 | 실패 | 미달 유지 |
| RTL co-sim | 7,680샘플 PASS | 미실시 | 검증 범위 차이 |

주기는 약 11.50% 짧아졌지만 LUT는 늘었다. 여러 변경을 합친 결과이므로 한 변경의 효과로 분리하지 않는다. [통합 문서의 코드·지표 비교](../VERSION_FINAL_RESULTS.md#8-현서-v1-최종본과-main-v21의-차이)와 [v2.1 원본 기록](result/v2.1/README.md)을 참고한다.
