# v2: II=2를 유지하는 15 ns 구현

v1.6의 합성·RTL 검증과 v1.7의 물리 구현 결과를 바탕으로, 활성화 ROM과 MAC 누산 구조를 변경했다. 현재 최종 채택본은 **v2.2**다.

| 버전 | 변경 | 실제 주기 | 판정 | 상세 |
|---|---|---:|---|---|
| v2.1 | 직접 조회 활성화 표를 BRAM ROM으로 구현 | 16.850 ns | 정확도·II=2 통과, timing 실패 | [상세](docs/v2.1_bram_rom.md) |
| **v2.2** | **BRAM ROM 유지 + 균형 MAC 트리** | **14.885 ns** | **정확도·II=2·15 ns 통과** | [상세](docs/v2.2_balanced_mac.md) |

전체 검증은 7,680샘플, 호출은 64샘플, 상태 초기화는 2,560샘플 간격이다. 처리율 판정에서 호출 오버헤드를 제외한다. 물리 구현 자원과 HLS 추정치는 구분한다.

- [버전별 이력](docs/experiment_history.md)
- [v0→v1→v2 누적 PPA](docs/ppa_history_template.md)
- [작업환경 가이드](docs/작업환경_가이드.md)
- [실행 조건](docs/PLAN.md)

소스·보고서는 `results/v2.1/`, `results/v2.2/`에 보존한다. 완료 결과 열람을 위해 재실행할 필요는 없다. 재현은 `scripts/run_version.py`를 사용하고 완료본을 덮어쓰거나 중복 실행하지 않는다.
