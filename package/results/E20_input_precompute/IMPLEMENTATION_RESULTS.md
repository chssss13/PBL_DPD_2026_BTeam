# E20 co-sim 및 실제 implementation 결과

기존 C 합성 RTL을 재사용했습니다. RTL co-sim 2,624샘플(리셋 경계 포함) PASS 및 C-sim Q14 코드 일치입니다.
E18과 같은 15 ns, Explore opt/place/route + 공유 데이터 연결 복제 + AggressiveExplore 물리 최적화 조합입니다.

| 결과 | WNS(ns) | TNS(ns) | WHS(ns) | STA 환산 주기(ns) | LUT | FF | DSP |
|---|---:|---:|---:|---:|---:|---:|---:|
| E18 reference | -1.157 | -347.371 | 0.023 | 16.157 | 60532 | 52281 | 722 |
| E20 route | -0.889 | -284.758 | 0.036 | 15.889 | 59878 | 52017 | 722 |
| E20 postroute | -0.844 | -278.463 | 0.036 | 15.844 | 59878 | 52017 | 722 |

최선 단계: postroute. E18 대비 WNS 개선량 +0.313 ns.
15 ns 전체 타이밍 통과: False.

코어 OOC 분석이며 보드 전체 I/O와 외부 클록 경로는 별도 검증 대상입니다.
실제 자원·타이밍은 이 구현 보고서로 판단하고 HLS 추정치와 구분합니다.
작업 소스의 최종 채택 상태는 README.md를 확인하세요.

- [route 타이밍](route/impl/verilog/report/ResGRU_timing_routed.rpt), [경로](route/impl/verilog/report/ResGRU_timing_paths_routed.rpt), [자원](route/impl/verilog/report/ResGRU_utilization_routed.rpt)

- [postroute 타이밍](postroute/impl/verilog/report/ResGRU_timing_routed.rpt), [경로](postroute/impl/verilog/report/ResGRU_timing_paths_routed.rpt), [자원](postroute/impl/verilog/report/ResGRU_utilization_routed.rpt)
