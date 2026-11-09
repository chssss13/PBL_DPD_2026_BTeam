# v3 후보별 flow 결과

[현재 진행표](batch/SUMMARY.md) · [계획](../docs/PLAN.md)

v3.1은 기존 v3 원본에서 만든 FEx inverse 16/5 통과본입니다. 이전 대칭 표 후보는 실제 삭제했습니다. v3.2는 v3.1에서 논문의 보정 seed로 NR 반복을 줄이는 자원 우선 후보입니다. 기준본의 새 HLS 재현은 실행하지 않습니다.

각 후보의 결과는 src/·tb/·config.json·changes.diff, 독립 참조 reference/, csim/·csynth/·cosim/·impl/과 state.json으로 구분합니다. 원본 보고서와 후보의 새 측정값을 혼합하지 않습니다.

II=2와 구현 후 15ns 통과는 필수입니다. 폐기된 후보는 상세 폴더와 문서를 삭제하며 따로 보관하지 않습니다. 삭제 작업이 도구 정책에 차단되면 삭제 완료로 표시하지 않습니다.
