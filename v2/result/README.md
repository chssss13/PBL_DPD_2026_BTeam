# v2 실험 결과와 보관 범위

sehyeon 브랜치의 구 v2.1~v2.3 초기 탐색 자료를 main에도 보관한다. 출처는 `d2e722658631957c278a8910b0666f243bd99cd1`이며, 세 폴더의 원본 바이트와 `manifest.sha256.json`을 유지했다.

| 단계 | 기준·주요 변경 | 비교 주기 | 보관 자료 |
|---|---|---:|---|
| [구 v2.1 탐색본](exploration-v2.1/README.md) | 현서 v1.7 기반; 누산기 축소·상태식·adder tree | 21.287 ns | 소스·TB·설정·정확도·로그·HLS/P&R 보고서 |
| [구 v2.2 탐색본](exploration-v2.2/README.md) | v2.1에서 512구간 보간 적용 | 18.649 ns | 소스·TB·설정·정확도·로그·HLS/P&R 보고서 |
| [구 v2.3 탐색본](exploration-v2.3/README.md) | v2.2에서 비트폭·보간 구간 축소, 중간 양자화 | 18.105 ns | 소스·TB·설정·정확도·로그·HLS/P&R 보고서 |
| [v2.1](v2.1/README.md) | sehyeon v1에서 별도 분기; 보간·비트 축소·게이트 분리 | 17.524 ns | [P&R 자원](v2.1/reports/implementation/utilization.rpt)·[타이밍](v2.1/reports/implementation/timing_summary.rpt) |
| [v2.2](v2.2/README.md) | GRU 누산 조정 | 17.310 ns | 상세 변경 이력 참조 |
| [v2.3](v2.3/README.md) | recurrent 곱셈 입력 항별 분리 | 16.427 ns | 상세 변경 이력 참조 |
| [v2 최종](final/README.md) | v2.1 이후 누산·항/행 분리·상태 갱신 개선 | 14.907 ns | 독립 재현 보관본·검증 결과 |

작업자는 sehyeon이며, 초기 구 v2.1~v2.3의 코드 출발점이 현서 v1.7이다. 현서 브랜치에서 같은 번호를 사용한 BRAM ROM·균형 MAC 실험과 구분한다. 상세 수치·판정은 [v2 개요](../README.md)와 각 버전 README를 따른다.

## 재현 의존성

구 v2.1~v2.3의 `source/reproduce.tcl`과 `source/evaluate.py`는 원래 `v2/package/` 아래의 golden 입력·가중치 및 PA 평가 도구·모델을 참조한다. 이 추가 작업은 실험 보관 자료를 가져온 것이며, main에 해당 공통 패키지 전체를 복사한 것은 아니다. 보고서·소스 열람과 해시 검증에는 공통 패키지가 필요 없다.

재실행하려면 [원본 공통 패키지](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/d2e722658631957c278a8910b0666f243bd99cd1/v2/package)를 같은 `v2/package/` 경로에 준비하고 각 버전 README의 환경·명령을 따른다. 세 버전은 RTL co-sim 미실시이며, 스크립트에 실행 옵션이 있다는 사실은 당시 검증 완료를 의미하지 않는다. 기존 보고서를 보존하고 새 실행 결과로 타이밍을 판단한다.
