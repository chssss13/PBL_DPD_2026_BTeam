# 새 v2 실험

버전별 상세: [실험 이력](docs/experiment_history.md), [v2.1](docs/v2.1_bram_rom.md),
[v2.2](docs/v2.2_balanced_mac.md), [폐기 v2.3](docs/v2.3_start_propagation_discarded.md),
[폐기 v2.4](docs/v2.4_ctrl_chain_discarded.md). 현재 유지할 설계는 v2.2다.

버전별 문서: [작업환경 가이드](docs/작업환경_가이드.md), [v0→v1→v2 누적 PPA](docs/ppa_history_template.md).

최신 분류: hidden state 식 변형 후보(실행 당시 새 v2.5)는
[v3.1](../v3/README.md)로 이관한다. v2의 채택 기준은 v2.2다.

[새 v2.5 hidden state 식 실험](docs/HIDDEN_STATE.md)을 진행한다.

현재 작업 범위는 새 v2.5 식 변형 결과까지다. 호출 오버헤드를 제외하고
15 ns/II2 기준 처리율과 정확도·실제 타이밍·자원을 보고한다. 추가 실험은 실행하지 않는다.

[계획과 판정 조건](docs/PLAN.md)에 따라 v2.1부터 한 버전씩 진행한다.
과거 v2.5의 소스와 실측 근거는 [독립 재현 패키지](../repro_v2_5/README.md)에 있다.
새 v2.2가 과거 v2.5의 두 활성 개선법을 합친 구성이다.

전체 순차 실행: `C:/Project/venv_dpd/Scripts/python.exe v2/scripts/run_flow.py`

진행 중에는 중복 실행하지 않는다. 현재 상태는 `results/v2.1/state.json`,
단계 로그와 `results/flow.log`, 완료 후 비교는 `results/STATUS.md`에서 확인한다.
v2.1이 15 ns를 통과하면 중단하고, 타이밍만 실패하면 v2.2를 순차 실행한다.
