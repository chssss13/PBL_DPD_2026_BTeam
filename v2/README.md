# v2 — v1에서 15 ns를 통과하기까지

main의 채택 흐름은 **세현 v1 → v2.1 → v2.2 → v2.3 → v2.4 최종**이다. 과거 v2.4-S를 v2.1로 정리했다. 현서 v1.7 기반의 초기 세 실험은 미채택 탐색본으로 별도 보관한다.

## 미채택 초기 탐색 · 현서 v1.7 기반

| 버전 | 변경 | PA NMSE (dB) | P&R LUT / FF / DSP | 비교 주기 (ns) |
|---|---|---:|---|---:|
| [구 v2.1 탐색본](result/exploration-v2.1/README.md) | 누산기 32/12→18/3, 상태식 정리, GRU adder tree | −43.66 | 70,412 / 48,482 / 636 | 21.287 |
| [구 v2.2 탐색본](result/exploration-v2.2/README.md) | sigmoid·tanh 512구간 선형 보간 | −45.48 | 58,319 / 48,897 / 564 | 18.649 |
| [구 v2.3 탐색본](result/exploration-v2.3/README.md) | data 15/3·weight 14/4, 보간 256구간·recurrent 중간 16/4 양자화 | −45.11 | 56,671 / 43,367 / 305 | 18.105 |

세 버전 모두 HLS II=2·PA 기준을 만족했지만 15 ns 타이밍은 실패했다. RTL co-sim은 미실시다. 각 폴더에 당시 소스·TB·정확도 출력·로그·HLS/P&R 보고서·SHA256 목록을 보관한다. [전체 결과 목록과 재현 의존성](result/README.md)을 참고한다.

## 채택 버전 · v2.1에서 최종본까지

아래는 sehyeon v1에서 시작한 최종 채택 계보의 비교다. 기존 변경 이력의 9~15번이 이 구간에 해당한다.

| 단계 | 적용한 변경 | 결과 |
|---|---|---|
| sehyeon v1 기준 → v2.1 | ① sigmoid·tanh의 4,096칸 직접 LUT를 256구간 선형 보간으로 바꾸고, data를 16/3→15/3, weight를 16/4→14/4로 줄임. ② recurrent 곱셈을 r·z·n 게이트별로 분리 | PA NMSE와 FPGA 자원이 개선됐다. 배선 후 비교 주기는 17.506→17.524 ns로 거의 같았다. |
| v2.2 | GRU 입력·recurrent 누산 21/6, 최종 18/3 변환 유지 | 17.310 ns, LUT 42,163 / FF 41,689 / DSP 333 |
| v2.3 | recurrent 곱셈을 게이트와 입력 항별로 분리 | 16.427 ns, LUT 41,735 / FF 41,383 / DSP 337 |
| v2.4 최종 | n recurrent 출력 행별 분리, z를 unsigned 12/0으로 변환, 최종 상태 포화만 제거 | 14.907 ns, 15 ns 통과. 동일 벡터 Q12 출력 일치 |

비트폭은 전체 비트 수/정수부 비트 수 순서다.

| 지표 | sehyeon v1 | v2.1 | v2.4 최종 |
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

¹ v2.4 최종은 같은 7,680샘플에서 Q12 출력이 일치해 v2.1 PA 결과를 이어 적었다. 비교 주기는 `15 ns − WNS`다.

- [sehyeon v1 측정 결과](https://github.com/chssss13/PBL_DPD_2026_BTeam/blob/d2e722658631957c278a8910b0666f243bd99cd1/result/07_lut_lookup/02_implementation/README.md)
- v2.1 [배치·배선 자원](result/v2.1/reports/implementation/utilization.rpt) · [타이밍](result/v2.1/reports/implementation/timing_summary.rpt)
- v2.4 최종 [소스·재현 안내](result/v2.4/README.md) · [단계별 코드 변경](result/v2.4/changes/코드변경.md)

## 현서 v1.7과 초기 탐색 첫 단계 비교

현서 v1.7에서 주요 누산기 32/12→18/3, 상태식 `(1-z)*n+z*h_prev`→`n+z*(h_prev-n)`, GRU 입력·recurrent 행렬곱 6곳의 5항 adder tree를 적용했다. data 16/3·weight 16/4, direct LUT, FEx inverse 16/8과 내부 double sqrt·역수는 유지했다. 입력·출력 FC의 순차 누산도 유지했다.

| 지표 | 현서 v1.7 | 구 v2.1 탐색본 | 변화 |
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

주기는 약 11.50% 짧아졌지만 LUT는 늘었다. 여러 변경을 합친 결과이므로 한 변경의 효과로 분리하지 않는다. [통합 문서의 코드·지표 비교](../VERSION_FINAL_RESULTS.md#52-현서-v17과-초기-탐색-첫-단계의-차이)와 [v2.1 원본 기록](result/exploration-v2.1/README.md)을 참고한다.
