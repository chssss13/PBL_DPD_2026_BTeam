# PBL_DPD_2026_BTeam

## LW-ResGRU FPGA 구현

| 버전 | 채택한 변경 | 결과와 재현 자료 |
|---|---|---|
| v2 | 활성화 보간·비트폭 조정, GRU 누산과 recurrent 곱셈 분리, 상태 갱신 최적화 | [v2 최종본](v2/result/final/README.md) · [v1 → v2.4-S → v2 최종 비교](v2/README.md) |
| v3 | sigmoid 대칭표, recurrent 곱 결과의 포화 제거, r/z bias 사전 합산 | [v3.1~v3.3 변경 이력](v3/README.md) |
| v4 | 출력 FC 정밀도와 FEx 개선, FIFO 및 파라미터 전달 최적화 | [v4.0~v4.6 변경·정확도·자원 비교](v4/README.md) |

기존 [v0](v0/)과 [v1](v1/) 자료도 확인할 수 있다.
