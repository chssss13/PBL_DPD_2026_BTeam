# E20: 독립 연산 사전 계산 — 공유 구현 기준

E18의 비트폭과 네트워크를 유지하고, 입력 MAC·바이어스 합을 자기 층의 이전 은닉 상태와 독립적으로 준비하도록 분리했습니다. hidden 후보 MAC+bias는 reset 게이트와 독립적으로 계산하고, z 및 retained product를 r→n 분기와 분리했습니다. 추가 클록 경계는 삽입하지 않았습니다. E19의 sigmoid8 변경은 포함하지 않습니다.

**다음 실험의 reference는 E20입니다.** 구현 입력은 이 폴더의 `src_snapshot/` 및 `tb_snapshot.cpp`에 고정했습니다. [새 clone 재현 안내](REPRODUCE.md)를 먼저 보세요.

## 검증된 결과

Vitis HLS / Vivado 2024.1, xczu7ev-ffvc1156-2-e, 코어 OOC, 목표 15 ns.

| 항목 | E20 |
|---|---:|
| 내부 LOOP_T II | 2 |
| C-sim | 7,680샘플, E18 Q14 출력 코드 전부 일치 |
| RTL co-sim | 2,624샘플 PASS, C-sim 코드 일치 |
| PA NMSE | -45.62 dB |
| ACPR L/R | -53.54 / -50.38 dBc |
| 실제 LUT / FF / DSP | 59,878 / 52,017 / 722 |
| BRAM / URAM | 0 / 0 |
| 배선 후 Setup WNS | -0.844 ns |
| STA 환산 주기 | 15.844 ns |

정확도·II=2·자원 한도는 통과했지만 **15 ns Setup 타이밍은 미달**입니다. E18 대비 WNS가 0.313 ns 개선됐습니다. PA 지표는 제공 대리모델의 평가이며 보드 실측이 아닙니다. STA 환산 주기는 목표 주기에서 WNS를 뺀 참고값으로, 해당 주기로 재구현한 결과는 아닙니다.

## 구현 조건

- data_t=16,2 / weight_t=16,4 / accum_t=18,3 / gate_t=20,5.
- 3 GRU층, hidden size 5, LUT 선형 보간, NR 4회, reset 2,560샘플 유지.
- Explore opt/place/route + 최대 8개 임계 공유 데이터 net 드라이버 복제 + AggressiveExplore phys_opt + post-route Explore.
- 복제는 Vivado Tcl에서 수행하므로 HLS 실행만으로 적용되지 않습니다.
- 모든 148,674개 net 배선 완료, 배선 오류와 최종 timing/조합 loop 0.

## 공유 자료

- [재현 절차 및 단계별 검사](REPRODUCE.md)
- [정확도 비교](RESULTS.md), [PA 원본 출력](PA_EVALUATION.txt)
- [C 합성·co-sim](HLS_COSIM_RESULTS.md), [co-sim 원본](ResGRU_cosim.rpt)
- [실제 구현 비교](IMPLEMENTATION_RESULTS.md)
- [postroute 타이밍](postroute/impl/verilog/report/ResGRU_timing_routed.rpt)
- [postroute 자원](postroute/impl/verilog/report/ResGRU_utilization_routed.rpt)
- [복제 대상](replication_targets.tsv), [소스 해시](source_hashes.json)

`evaluation.json`과 `RESULTS.md`는 선행 C-sim 단계의 이력입니다. 이후 C 합성·co-sim·implementation 완료 상태는 위 최종 요약과 후속 보고서를 기준으로 보세요. 생성 프로젝트·DCP·캐시는 재생성하며 저장소에 넣지 않습니다.
