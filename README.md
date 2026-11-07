# PBL_DPD_2026_BTeam
## `sehyeon` 브랜치 현재 결과

현재 채택본은 **원본 sehyeon v1을 개선한 v3.2**다. [v3.2 코드·검증·재현](v3/result/v3.2/README.md). 아래 표는 이전 v2 최종 결과다. Vitis HLS/Vivado 2024.1, `xczu7ev-ffvc1156-2-e`, IP 내부 15 ns 클록 조건에서 검증했다.

| 항목 | 최종 결과 |
|---|---:|
| C-sim | 7,680개 입력, 참조와 Q12 일치 |
| RTL co-sim | 최종 소스 별도 재합성, Verilog/XSim 7,680개 PASS |
| HLS LOOP_T II | 2 |
| P&R WNS / setup·hold 위반 | +0.093 ns / 0개 |
| P&R LUT / FF / DSP / BRAM | 41,387 / 41,088 / 362 / 0 |

[최종 코드·재현 방법](v2/result/final/README.md) · [v1/v2 변경 요약](v2/result/final/docs/v1_v2_변경요약.md) · [논문 아키텍처 대응](v2/result/final/docs/v1기반_변경과_논문아키텍처_대응.md)

15 ns와 WNS로 계산한 비교 주기는 14.907 ns다. 최악 데이터 경로 지연 14.888 ns와 구분한다. 외부 I/O 통합 타이밍·보드 실측은 별도다.

[PPA 주차별 이력](PPA_주차별_이력.md) · [v1 기록](v1_의사결정_합성요약.md) · [v2 버전별 비교](v2/README.md) · [채택 변경 이력](v2/result/final/docs/v1기반_채택변경_이력.md)

[v3 실험 계열·기록](v3/README.md) · [v3.1 코드·결과](v3/result/v3.1/README.md) · [v3.2 현재 최종본](v3/result/v3.2/README.md)
