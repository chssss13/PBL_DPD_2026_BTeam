# v2 버전별 실험 이력

현재 v2는 v1.6/v1.7에서 정확도와II2를 유지하며15ns를 맞춘 계열이다.
이전에 삭제한 실험 계열과 번호가 재사용됐으므로 아래 문서를 현재 계열의 기준으로 삼는다.
호출 오버헤드는 최종 목표 판정에서 제외한다.

| 버전 | 기반 / 변경 | 실제 구현 주기 | 판정 | 상세 |
|---|---|---:|---|---|
| v2.1 | v1.6/v1.7 → BRAM activation ROM | 16.850ns | 정확도·II2 PASS,15ns FAIL | [상세](v2.1_bram_rom.md) |
| v2.2 | v2.1 → 균형 MAC 트리 | 14.885ns | 정확도·II2·15ns PASS, 채택 | [상세](v2.2_balanced_mac.md) |
| v2.3 | v2.2 → start propagation 제거 | 미측정 | 개선 없어 폐기 | [실패 이력](v2.3_start_propagation_discarded.md) |
| v2.4 | v2.2 → ap_ctrl_chain | 미측정 | 개선 없어 폐기 | [실패 이력](v2.4_ctrl_chain_discarded.md) |

식 변형은 실행 당시 새 v2.5였지만 [v3.1](../../v3/docs/v3.1_hidden_state.md)로 이관했다.
별도 과거 v2.5는 [repro_v2_5](../../repro_v2_5/README.md)에 보존한다.
현재 v2.2와 같은 활성 개선법·실측 성능이며 현재의 v3.1과 구별한다.

- 누적 수치: [PPA 이력표](ppa_history_template.md)
- 환경·실행: [작업환경 가이드](작업환경_가이드.md)
- v2.1/v2.2는 실제 원시 소스·로그·보고서 보존, 폐기 후보는 요약 기록만 보존했다.
