# PBL_DPD_2026_BTeam

현재 채택본은 **[v4.1](v4/result/v4.1/README.md)**(기존 v3.5), 기준선은 **[v4.0](v4/result/v4.0/README.md)**(기존 v3.4)이다. [정확도·자원·타이밍 비교](v4/README.md).

기존 v4.0~v4.6 계열은 [미사용 보관본](v4_unused/README.md)으로 전환했다. 새 v4와는 별도 계열이다.
## 이전 v1~v3 결과

아래는 이전 v2 최종 결과다. 현재 채택본과 비교는 [새 v4 계열](v4/README.md)을 확인한다.

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

[v3 실험 계열·기록](v3/README.md) · [v3.1 코드·결과](v3/result/v3.1/README.md) · [v3.2 코드·결과](v3/result/v3.2/README.md) · [v3.3 과거 채택본](v3/result/v3.3/README.md)
