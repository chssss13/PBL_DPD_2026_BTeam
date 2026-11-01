# v2 — v1.7 기반 타이밍 개선

**현재 기록: v2.3 P&R 완료까지.** 정확도와 HLS II=2를 유지하면서 배치·배선 후 15 ns 달성을 목표로 한다. 현재는 18.105 ns로 목표 미달이다.

## 기준 코드와 범위

- 작업 브랜치: `sehyeon`.
- 기준: [hyeonseo 고정 커밋의 v1](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/c8389599d24a4be360ac84ba243f6886f986f340/v1). v1.7 시점 소스를 가져왔고 기본 HLS 실행 조건은 해당 브랜치 v1.6 II=2 후보 설정이다.
- 최초 가져오기 파일 목록은 [baseline.json](baseline.json), 각 실험의 소스와 해시는 결과 폴더에 있다. 현재 `package/`는 v2.3 코드다.
- 루트의 기존 `package/`, `result/`와 v1 기록은 이전 `sehyeon` 브랜치 기록이다. `package/docs/`의 v1 문서는 원본 브랜치 기록이다.

## 변경 사항과 결과

| 단계 | 변경 | PA NMSE | HLS II | 배선 후 주기 / WNS |
|---|---|---:|---:|---:|
| [v2.1](result/v2.1/README.md) | accum 축소, 상태 갱신식, GRU adder tree | -43.66 dB | 2 | 21.287 / -6.287 ns |
| [v2.2](result/v2.2/README.md) | 512구간 선형 보간 | -45.48 dB | 2 | 18.649 / -3.649 ns |
| [v2.3](result/v2.3/README.md) | 자료형 축소, 256구간 보간, 중간값 양자화 | -45.11 dB | 2 | 18.105 / -3.105 ns |

## 정확도와 타이밍 기준

| 지표 | 기준 | v2.1 | v2.2 | v2.3 |
|---|---:|---:|---:|---:|
| PA NMSE (dB) | ≤ -43.48 | -43.66 | -45.48 | -45.11 |
| PA ACPR L (dBc) | ≤ -50.39 | -51.92 | -53.44 | -53.02 |
| PA ACPR R (dBc) | ≤ -47.83 | -48.52 | -50.30 | -49.87 |
| HLS LOOP_T II | 2 | 2 | 2 | 2 |
| 배선 후 주기 (ns) | ≤ 15 | 21.287 | 18.649 | 18.105 |

정확도는 7,680샘플 C-sim 출력의 PA 평가다. 세 버전 모두 RTL co-sim과 보드 실측은 수행하지 않았다. HLS II=2만으로 15 ns 처리 목표를 달성한 것은 아니다.

## 공통 실행 조건

Vitis HLS / Vivado 2024.1, FPGA `xczu7ev-ffvc1156-2-e`, 목표 15 ns, HLS uncertainty 1 ns, DSP full reg false, LOOP_T II=2 요청, FEx inverse `16,8`, 2,560샘플 상태 초기화. 자료형과 활성화 표는 버전마다 다르며 상세 보고서에 명시했다. v2.3 소스는 `ACT_LUT=3`으로 실행한다.

## 최종 하드웨어 사용량

아래 수치는 Vivado 배치·배선 후 결과다.

| 자원 | [v1.7](package/docs/v1.7_implementation.md) | v2.1 | v2.2 | v2.3 |
|---|---:|---:|---:|---:|
| LUT | 66,859 | 70,412 | 58,319 | 56,671 |
| FF | 49,754 | 48,482 | 48,897 | 43,367 |
| DSP | 711 | 636 | 564 | 305 |
| BRAM | 0 | 0 | 0 | 0 |

[상세 보고서와 근거 파일](result/README.md)
