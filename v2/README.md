# v2 — 2주차 타이밍 개선

정확도와 HLS II=2를 유지하면서 배치·배선 후 15 ns 달성을 목표로 한다. hyeonseo v1.7 기반 v2.1~v2.3과 원본 sehyeon v1에서 별도로 분기한 [v2.4-S](result/v2.4-S/README.md)를 함께 기록한다. v2.4-S 이후 채택한 다섯 변경을 누적한 현재 최종본은 IP 내부 15 ns 타이밍을 통과했다.

**현재 최종 채택(2026-11-03):** sehyeon v1 계보의 [최종 코드·재현 보관본](result/final/README.md). C-sim 7,680개 Q12 일치, HLS II=2, IP 내부 15 ns 제약에서 **WNS +0.093 ns, setup/hold 위반 0개**다. P&R 자원은 **LUT 41,387 / FF 41,088 / DSP 362 / BRAM 0**이다. 비교 주기 14.907 ns와 데이터 경로 지연 14.888 ns는 구분한다. [변경 요약](result/final/docs/v1_v2_변경요약.md) · [채택 이력](result/final/docs/v1기반_채택변경_이력.md)

## 기준 코드와 범위

- 작업 브랜치: `sehyeon`.
- 기준: [hyeonseo 고정 커밋의 v1](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/c8389599d24a4be360ac84ba243f6886f986f340/v1). v1.7 시점 소스를 가져왔고 기본 HLS 실행 조건은 해당 브랜치 v1.6 II=2 후보 설정이다.
- 최초 가져오기 파일 목록은 [baseline.json](baseline.json), 각 실험의 소스와 해시는 결과 폴더에 있다. `package/src/`를 v2.4-S 소스로 바꾸지는 않았으며 v2.4-S는 별도 [보관 소스](result/v2.4-S/source/src/), 현재 최종본은 [final/src](result/final/src/)를 기준으로 한다.
- 루트의 기존 `package/`, `result/`와 v1 기록은 이전 `sehyeon` 브랜치 기록이다. `package/docs/`의 v1 문서는 원본 브랜치 기록이다.

## 변경 사항과 결과

| 단계 | 변경 | PA NMSE | HLS II | 배선 후 주기 / WNS |
|---|---|---:|---:|---:|
| [v2.1](result/v2.1/README.md) | accum 축소, 상태 갱신식, GRU adder tree | -43.66 dB | 2 | 21.287 / -6.287 ns |
| [v2.2](result/v2.2/README.md) | 512구간 선형 보간 | -45.48 dB | 2 | 18.649 / -3.649 ns |
| [v2.3](result/v2.3/README.md) | 자료형 축소, 256구간 보간, 중간값 양자화 | -45.11 dB | 2 | 18.105 / -3.105 ns |
| [v2.4-S](result/v2.4-S/README.md) | **sehyeon v1 별도 분기**; 256구간 보간·비트 축소·recurrent 게이트 분리 | -44.97 dB | 2 | 17.524 / -2.524 ns |
| [현재 최종](result/final/README.md) | 누산 폭 확대·항/행별 분리·z unsigned12·상태 최종 포화 생략 | -44.97 dB¹ | 2 | 14.907 / +0.093 ns |

¹ 최종 단계에서는 동일 입력에서 저장된 참조와 Q12 출력 일치를 확인했다. PA 모델을 최종 후보로 새로 실행한 수치는 아니며 [검증 범위](result/final/reports/결과요약.md)를 따른다.

## 정확도와 타이밍 기준

| 지표 | 기준 | v2.1 | v2.2 | v2.3 |
|---|---:|---:|---:|---:|
| PA NMSE (dB) | ≤ -43.48 | -43.66 | -45.48 | -45.11 |
| PA ACPR L (dBc) | ≤ -50.39 | -51.92 | -53.44 | -53.02 |
| PA ACPR R (dBc) | ≤ -47.83 | -48.52 | -50.30 | -49.87 |
| HLS LOOP_T II | 2 | 2 | 2 | 2 |
| 배선 후 주기 (ns) | ≤ 15 | 21.287 | 18.649 | 18.105 |

정확도는 7,680샘플 C-sim 출력의 PA 평가다. v2.1~v2.4-S 모두 RTL co-sim과 보드 실측은 수행하지 않았다. HLS II=2만으로 15 ns 처리 목표를 달성한 것은 아니다. v2.4-S의 항목별 기준·비교는 [상세 보고서](result/v2.4-S/README.md)에 있다.

## 공통 실행 조건

Vitis HLS / Vivado 2024.1, FPGA `xczu7ev-ffvc1156-2-e`, 목표 15 ns, HLS uncertainty 1 ns, DSP full reg false, LOOP_T II=2 요청, FEx inverse `16,8`, 2,560샘플 상태 초기화. 자료형과 활성화 표는 버전마다 다르며 상세 보고서에 명시했다. v2.3 소스는 `ACT_LUT=3`으로 실행한다.

위 FEx inverse `16,8`은 v2.1~v2.3 기준이다. 별도 계보인 v2.4-S는 원본 v1 FEx의 Newton–Raphson 4회 및 inverse `16,6`을 사용한다.

## 최종 하드웨어 사용량

아래 수치는 Vivado 배치·배선 후 결과다.

| 자원 | [v1.7](package/docs/v1.7_implementation.md) | v2.1 | v2.2 | v2.3 | v2.4-S | 현재 최종 |
|---|---:|---:|---:|---:|---:|---:|
| LUT | 66,859 | 70,412 | 58,319 | 56,671 | 47,575 | 41,387 |
| FF | 49,754 | 48,482 | 48,897 | 43,367 | 41,799 | 41,088 |
| DSP | 711 | 636 | 564 | 305 | 333 | 362 |
| BRAM | 0 | 0 | 0 | 0 | 0 | 0 |

v2.4-S는 v2.3 계보가 아닌 sehyeon v1 기준이다. 별도 구현이므로 자원 차이를 한 가지 변경의 효과로 볼 수 없다.

[상세 보고서와 근거 파일](result/README.md)
