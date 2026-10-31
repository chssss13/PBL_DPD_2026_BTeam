# v2 — 현서 님 v1 기반 타이밍 개선

**현재 기록: v2.2의 두 번째 P&R 완료까지.** 정확도와 HLS II=2를 유지하면서 Vivado 배치·배선 후 15 ns 달성을 목표로 한다. 현재는 18.649 ns로 목표 미달이다.

## 기준 코드와 범위

- 작업 브랜치: `sehyeon`.
- 기준: [hyeonseo 고정 커밋의 v1](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/c8389599d24a4be360ac84ba243f6886f986f340/v1). v1.7 시점의 소스를 가져왔으며 기본 HLS 실행 조건은 해당 브랜치의 v1.6 II=2 후보 설정이다.
- 가져온 원본 파일 목록·해시는 [baseline.json](baseline.json)에 있다. 이 파일은 최초 가져오기 시점의 기록이며 현재 수정된 소스의 해시는 각 결과 폴더에 있다.
- `package/`는 v2.2 코드다. v2.1과 v2.2의 검증 당시 코드는 각각 결과 폴더 `source/`에 별도 보존했다.
- 루트의 기존 `package/`, `result/`와 v1 기록은 세현 v1이며 변경하지 않았다. 가져온 `package/docs/` 문서 중 v1 관련 기록은 원본 작성자의 기록이다.

## 변경 사항 → 결과

| 단계 | 의사결정 | 정확도 / HLS | 배선 후 결과 |
|---|---|---|---|
| [v2.1](result/v2.1/README.md) | accum 32,12→18,3, 상태 갱신식 정리, GRU 5항 adder tree | NMSE -43.66 dB, II=2 | 21.287 ns / WNS -6.287 ns |
| [v2.2](result/v2.2/README.md) | 위 조건 유지, direct LUT를 512구간 정수 선형 보간으로 변경 | NMSE -45.48 dB, II=2 | 18.649 ns / WNS -3.649 ns |

## 정확도와 타이밍 기준

| 지표 | 기준 | v2.1 | v2.2 |
|---|---:|---:|---:|
| PA NMSE (dB) | ≤ -43.48 | -43.66 | -45.48 |
| PA ACPR L (dBc) | ≤ -50.39 | -51.92 | -53.44 |
| PA ACPR R (dBc) | ≤ -47.83 | -48.52 | -50.30 |
| HLS LOOP_T II | 2 | 2 | 2 |
| 배선 후 주기 (ns) | ≤ 15 | 21.287 | 18.649 |

정확도는 7,680샘플 C-sim 출력의 PA 평가다. Python 비교는 통과했으며 두 버전의 RTL co-sim과 보드 실측은 수행하지 않았다. HLS II=2를 달성해도 15 ns 처리 목표를 달성한 것은 아니다.

## 공통 실행 조건

Vitis HLS / Vivado 2024.1, FPGA `xczu7ev-ffvc1156-2-e`, 목표 15 ns, HLS uncertainty 1 ns, DSP full reg false, LOOP_T II=2 요청. data `16,3` / weight `16,4` / accum `18,3`, FEx inverse `16,8`, 2,560샘플 상태 초기화. Vivado 옵션과 실제 실행 로그는 각 보고서에 보존했다.

환경 설정 파일이나 생성 프로젝트 대신 실행에 필요한 소스·TB·도구·golden·PA 모델을 제공한다. 버전별 상대 경로 재현 명령은 각 보고서의 ‘재현’ 절을 따른다.

## 최종 하드웨어 사용량

아래 수치는 HLS 추정치가 아닌 Vivado 배치·배선 후 결과다.

| 자원 | [현서 님 v1.7](package/docs/v1.7_implementation.md) | v2.1 | v2.2 |
|---|---:|---:|---:|
| LUT | 66,859 | 70,412 | 58,319 |
| FF | 49,754 | 48,482 | 48,897 |
| DSP | 711 | 636 | 564 |
| BRAM | 0 | 0 | 0 |

[상세 보고서와 근거 파일](result/README.md)
