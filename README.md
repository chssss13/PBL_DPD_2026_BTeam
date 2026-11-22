# PBL_DPD_2026_BTeam

## LW-ResGRU FPGA 구현

v0 및 v1~v4 최종본의 PPA 비교는 [PPA_COMPARISON.md](PPA_COMPARISON.md)에서 확인한다.

현재 채택 최종본은 **[v4.7](v4/result/v4.7/README.md)**이다. 배치·배선 기준 LUT **20,069**, FF **19,200**, DSP **347**, BRAM **7.5타일**, 비교 주기 **14.949 ns**(목표 15 ns)다. 동일 평가 벡터의 PA NMSE는 **−45.19 dB**이며, 정확도와 검증 범위는 [v4 비교](v4/README.md)에 정리했다.

main의 채택 흐름은 **세현 v1 → v2.1 → v2.2 → v2.3 → v2.4 최종 → v3.3 → v4.7**이다. 과거 v2.4-S를 v2.1로 정리했다. 현서 v1.7 기반의 초기 세 실험은 미채택 탐색본으로 별도 보관한다. [통합 결과 문서](VERSION_FINAL_RESULTS.md)에서 세부 변경과 지표를 확인할 수 있다.

처음 읽을 때는 통합 결과 → 버전별 요약 → 개별 버전 README → 소스·보고서 순서로 확인한다. 실행하려면 먼저 [버전별 재현 자료 범위](v4/README.md#재현-자료와-확인-순서)를 확인한다. 결과 보관 자료와 바로 실행 가능한 재현 패키지는 구분한다.

| 버전 | 채택한 변경 | 결과와 재현 자료 |
|---|---|---|
| v1 | 현서 v1.7: 정확도 복구·LUT 활성화·II=2 확보, 15 ns 타이밍 미달 | [최종 구현](v1/docs/v1.7_implementation.md) · [PPA 이력](v1/docs/ppa_history_template.md) |
| v2 | 활성화 보간·비트폭 조정, GRU 누산과 recurrent 곱셈 분리, 상태 갱신 최적화 | [v2.4 최종본](v2/result/v2.4/README.md) · [현서 v1.7에서 v2.4 최종까지](v2/README.md) |
| v3 | sigmoid 대칭표, recurrent 곱 결과의 포화 제거, r/z bias 사전 합산 | [v3.1~v3.3 변경 이력](v3/README.md) |
| v4 | 출력 FC 정밀도와 FEx 개선, FIFO 및 파라미터 전달 최적화 | [v4.0~v4.7 변경·정확도·자원 비교](v4/README.md) |

기존 [v0](v0/)과 [v1](v1/) 자료도 확인할 수 있다.
