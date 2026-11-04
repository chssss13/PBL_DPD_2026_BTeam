# PBL_DPD_2026_BTeam

## 버전 및 현재 결과

호출 오버헤드를 제외한 II·구현 타이밍 기준으로 평가한다.
Vitis HLS/Vivado2024.1, xczu7ev-ffvc1156-2-e, 목표15ns.

| 계열 | 내용 | 현재 판정 | 문서 |
|---|---|---|---|
| v0 | 원본 재현 | 정확도·15ns 미달 | [PPA](v0/docs/ppa_history_template.md) |
| v1 | 수치·활성화·스케줄 변경 | v1.6/v1.7: 정확도·II2 통과,15ns 미달 | [이력](v1/docs/experiment_history.md) |
| v2 | BRAM activation ROM + 균형 MAC | **v2.2 채택:14.885ns,II2,정확도 PASS** | [버전별 상세](v2/docs/experiment_history.md) |
| v3 | hidden state 식 재구성 | v3.1 폐기:DSP711→646,15.410ns로15ns 실패 | [버전별 상세](v3/docs/experiment_history.md) |

v2.3/v2.4는 개선이 없어 폐기했다. v3.1은 새 v2.5로 실행한 뒤 이름을 변경했으며,
과거 v2.5의 독립 보존본 [repro_v2_5](repro_v2_5/README.md)와 구별한다.
보존본은 소스·가중치·참조·RTL·원본 보고서·체크포인트를 포함한다.
생성 HLS 프로젝트와 Python 캐시는 Git에서 제외한다.

누적 PPA는 각 계열의 `docs/ppa_history_template.md`,
환경·실행 안내는 `docs/작업환경_가이드.md`에 있다.
HLS 추정 자원과 실제 구현 자원, 미측정과 실패를 구분해 기록한다.
