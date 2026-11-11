# PBL_DPD_2026_BTeam

## 버전 및 현재 결과

호출 오버헤드를 제외한 II·구현 타이밍 기준으로 평가한다.
Vitis HLS/Vivado2024.1, xczu7ev-ffvc1156-2-e, 목표15ns.

| 계열 | 내용 | 현재 판정 | 문서 |
|---|---|---|---|
| v0 | 원본 재현 | 정확도·15ns 미달 | [PPA](v0/docs/ppa_history_template.md) |
| v1 | 수치·활성화·스케줄 변경 | v1.6/v1.7: 정확도·II2 통과,15ns 미달 | [이력](v1/docs/experiment_history.md) |
| v2 | BRAM activation ROM + 균형 MAC | **v2.2 채택:14.885ns,II2,정확도 PASS** | [버전별 상세](v2/docs/experiment_history.md) |
| v3 | FEx 정밀도·seed·sigmoid multipartite·합성 설정·곱 포화 최적화 | **v3.5 채택:14.893ns,II2,정확도 PASS** | [버전별 결과](v3/results/README.md) |

현재 v3 최종본은 [v3.5](v3/docs/v3.5_sehyeon_incremental.md)다. LUT 37,311 / FF 41,308 / DSP 355 / BRAM 0이며 전체 7,680샘플 C·독립 참조·RTL 검증 및 PA 기준을 통과했다. v3.1~v3.4 채택본도 보존한다. 현재 실행·예약 작업은 없다.
II=2와 구현 후 15ns는 반드시 유지하며, 실질적 개선이 없는 후보는 파일을 삭제한다.
로컬 실험과 잘못 추가한 sehyeon v3.3 재현·R00~R02는 작업 폴더에서 제거했다.
주간 목표는 정확도 개선과 자원 감소이며15ns·II2 조건은 유지한다.

v2.3/v2.4는 개선이 없어 폐기했다. 기존 식 변형 v3.1도 폐기했고 Git 이력으로 보존한다.
v3/src 등은 기존 sehyeon v2 최종본 원본을 그대로 보존한다.
기존 식 변형 v3.1은 새 v2.5로 실행한 뒤 이름을 변경했으며,
과거 v2.5와 구별한다. 과거 독립 보존본은
[Git 이력](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/e34aa860ff7744f60990f2ef2b1c8765efb16628/repro_v2_5)에 남아 있다.
현재 v2.2 실행에는 별도 repro_v2_5 폴더가 필요하지 않다.
생성 HLS 프로젝트와 Python 캐시는 Git에서 제외한다.

누적 PPA는 각 계열의 `docs/ppa_history_template.md`,
환경·실행 안내는 `docs/작업환경_가이드.md`에 있다.
HLS 추정 자원과 실제 구현 자원, 미측정과 실패를 구분해 기록한다.

## 현재 필요한 파일

- `v2/`: 현재 채택본 v2.2의 소스·TB·입력·모델·실행 스크립트·보고서·문서. 실행과 검증에 필요하다.
- `v0/`, `v1/`: 이전 버전의 비교 근거와 개발 이력. v2.2 실행 자체의 의존성은 아니다.
- `v3/`: 기준 원본과 v3.1~v3.5 채택 소스·TB·입력·스크립트·검증 보고서를 포함한다. 최종 소스는 `v3/experiments/v3.5/src/`이며 `v3/src/`는 기준 원본이다.
- [v3 공유 ZIP](v3_hyeonseo.zip): 누적 PPA, 버전별 상세 문서·소스·결과 및 검증 근거를 포함한다.
- [최종 브랜치별 v2 ZIP](v2_branch_files_20261105_151533.zip): 외부 전달용 자료.
- [최종 비교 MD](v2_branch_comparison_20261105_151533.md): 최신 브랜치별 비교.

`repro_v2_5/`, `comparisons/`, `deliverables/`는 현재 필수 폴더가 아니다.
루트에 옮긴 위 최종 ZIP·MD만 전달 자료로 사용한다. 초기 ZIP 묶음은 사용하지 않는다.
