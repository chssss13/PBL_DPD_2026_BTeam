# v3.2: 보정 seed와 정규화 NR 1회

2026-11-09. 기준은 **채택된 v3.1**이며, 아래 수치는 완료된 해당 후보의 전체 flow 결과다. 판정: **accepted**.

## 변경 목적과 코드

v3.1의 inverse 16/5를 유지하며 Taylor 초기식과 NR 4회를 정규화·보정 seed·NR 1회·역정규화로 대체했다. amp2의 최상위 비트로 입력을 [1,2)로 정규화하고 64항 보정 표를 사용한다. amp2=0에서는 inverse=0으로 정의한다. 나머지 GRU와 활성화 계산은 부모와 같다.

```cpp
// m: 정규화된 [1,2) 입력
// seed = 5/4 - m/4 + correction[index]
y = y * (1.5 - 0.5 * m * y * y); // NR 1회
// 홀수 지수 보정 46341(Q16), 역정규화 후 inverse 16/5로 반올림·포화
```

[논문 원문](https://perso.ens-lyon.fr/jean-michel.muller/EMTAsilomar05.pdf). Simple Seed Architectures for Reciprocal and Square Root Reciprocal의 III절 polynomial-plus-correction seed가 근거다. 고정소수점 정규화·역정규화와 0 처리는 현재 FEx에 맞춘 자체 설계다. 표는 정규화 영역에서 구성하며 I/Q 데이터로 학습하지 않았다.

[전체 코드 변경](../../experiments/v3.2/changes.diff) · [검증 소스와 설정](../../experiments/v3.2/)

## 공통 실행 조건

| 항목 | 설정 |
|---|---|
| 도구 / FPGA | Vitis HLS·Vivado 2024.1 / xczu7ev-ffvc1156-2-e |
| 구현 클록 / HLS uncertainty | 15 ns / 1 ns |
| DSP full register / 구현 전략 | false / default |
| GRU 구조 | hidden=5, 입력 투영 차원=5, 3층 |
| 호출 / 전체 검증 / reset | 64샘플 / 7,680샘플 / 2,560샘플 |
| data / weight | signed 15/3(Q12) / signed 14/4(Q10) |
| 주요 GRU 누산 | 곱별 18/3 → 누산 21/6 → 최종 18/3 |
| 반올림 / 포화 | AP_RND / AP_SAT; 상태 최종 변환의 범위 검증된 AP_WRAP 유지 |
| FEx inverse / NR | signed 16/5(Q11) / 정규화 1회 |
| 활성화 | sigmoid·tanh 256구간 선형 보간 |

처리율은 호출 오버헤드를 제외한다. 15 ns·II=2에서 정상상태 목표는 33.333 MSps다. 보고 주기의 환산 처리율은 `1000 / 주기(ns) / II`이며, 보드 실측이나 호출 오버헤드를 포함한 처리율이 아니다. 전력은 미측정이다.

## 기능·정확도·스케줄 검증

| 항목 | 결과 |
|---|---|
| C/독립 Python 정수 참조 | 전체 7,680샘플, Q12 성분 불일치 0개 |
| C/RTL co-simulation | Verilog PASS, 전체 C 출력과 일치 |
| 실제 LOOP_T II | 2 |
| 단위 연산 검증 | 표현 가능한 amp2 코드 16,384개 전수 C/독립 참조 비교 |
| RTL 호출 지연 min/avg/max | 145 / 145 / 145 cycles |
| RTL 호출 간격 min/avg/max（참고） | 134 / 134 / 134 cycles; 목표 판정에서 제외 |

여기서 기능 일치는 **후보의 수치 연산을 반영한 독립 참조와 C**, 그리고 **동일 후보의 C와 RTL** 사이의 일치다. 수치 형식·근사식을 바꿨으므로 기존 v3 출력과 bit-exact라는 의미는 아니다.

| PA 지표 | 부모 | 후보 | 부모 대비(dB) | 공식 기준 |
|---|---:|---:|---:|---:|
| NMSE | -44.960049 | -45.123500 | -0.163452 | ≤ -43.48 |
| ACPR_L | -53.607991 | -53.390235 | +0.217756 | ≤ -50.39 |
| ACPR_R | -50.306152 | -50.076574 | +0.229578 | ≤ -47.83 |
| EVM (참고) | -48.753367 | -48.872463 | -0.119096 | 판정 대상 아님 |

NMSE·EVM은 dB, ACPR은 dBc다. 변화의 음수는 개선이다. PA는 제공 모델로 2,560샘플×3구간을 평가했다. 최종 수치는 C 출력의 PA 평가이며, RTL은 전체 C 출력과 일치함을 별도로 확인했다.

## 실제 구현 지표 및 부모 대비 변화

| 항목 | 부모 | 후보 | 변화 |
|---|---:|---:|---:|
| LUT | 41,179 | 40,785 | -394 (-0.96%) |
| FF | 41,132 | 41,227 | +95 (+0.23%) |
| DSP | 362 | 355 | -7 (-1.93%) |
| BRAM_18K | 0 | 0 | +0 |
| Post-Route 주기(ns) | 14.750 | 14.952 | +0.202 |
| WNS(ns) | +0.250 | +0.048 | -0.202 |

WHS **+0.037 ns**, routing errors=0, unrouted nets=0. 실제 구현 15 ns 판정: **PASS**. 보고 주기 환산 정상상태 처리율은 **33.440 MSps**다.

BRAM은 18K 환산 값이다. SRL은 LUT에 포함되므로 별도 합산하지 않는다. HLS 추정치는 아래에 분리한다.

## 기존 v3 기준 원본 대비 누적 변화

| 항목 | v3 원본 | 후보 | 원본 대비 |
|---|---:|---:|---:|
| LUT | 41,387 | 40,785 | -602 (-1.45%) |
| FF | 41,088 | 41,227 | +139 (+0.34%) |
| DSP | 362 | 355 | -7 (-1.93%) |
| BRAM_18K | 0 | 0 | +0 |
| PA NMSE | -44.968247 | -45.123500 | -0.155253 dB |
| PA ACPR_L | -53.345506 | -53.390235 | -0.044729 dB |
| PA ACPR_R | -50.080454 | -50.076574 | +0.003880 dB |

원본의 물리 주기는 14.907 ns다. 원본 PA 값은 동일 평가 스크립트로 기존 C 출력을 재평가한 값이며, 원본 HLS 재실행 결과가 아니다.

## HLS 합성 추정 — 실제 구현과 구분

| LUT 추정 | FF 추정 | DSP 추정 | BRAM_18K 추정 | 추정 주기(ns) |
|---:|---:|---:|---:|---:|
| 221,368 | 127,398 | 482 | 0 | 13.881 |

## 해석과 채택 판정

DSP가 7개(1.93%) 줄고 FF 증가는 0.23%에 머물러 자원 채택 기준을 만족했다. LUT는 0.96% 감소했다. NMSE는 0.163452 dB 개선됐지만 ACPR 좌/우는 0.217756/0.229578 dB 악화됐다. 공식 PA 기준을 모두 통과하므로 자원 개선 경로로 채택했다. 모든 정확도 지표가 개선된 결과는 아니다.

15 ns 제약의 setup 여유는 0.048 ns다. 더 높은 주파수의 동작이나 모든 입력에서의 모델 정확도·전력 개선을 주장하지 않는다.

## 소스·보고서 및 재현

- [소스·설정·차이](../../experiments/v3.2/)
- [C/독립 참조 비교](evidence/csim/quality.json)
- [PA 평가 전체 정밀도 수치](evidence/csim/pa_metrics.json)
- [RTL 비교](evidence/cosim/quality.json) · [RTL cosim 보고서](evidence/cosim/reports/ResGRU_cosim.rpt)
- [구현 요약](evidence/impl/reports/summary/verilog/export_impl.rpt)
- [실제 자원](evidence/impl/reports/detail/ResGRU_utilization_routed.rpt)
- [setup/hold](evidence/impl/reports/detail/ResGRU_timing_routed.rpt)
- [배선 상태](evidence/impl/reports/detail/ResGRU_status_routed.rpt)
- [자동화 상태·소스 해시](state.json)

저장소 루트에서 `C:/Project/venv_dpd/Scripts/python.exe v3/scripts/run_flow.py v3.2`. 완료된 stage는 재합성하지 않고 기존 검증 상태를 사용한다. 결과 열람만 하려면 실행할 필요가 없다.

처음부터 재구축하려면 별도 작업 복사본에서 해당 실험의 prj_candidate와 결과 경로를 새로 준비한다. 기존 결과 덮어쓰기와 실행 중 후보의 중복 실행은 피한다. PA 재평가에는 v2/opendpd_min 및 PA 모델, 기능 비교에는 v2/tools/compare_out.py가 필요하다. 물리 최적화에 따라 재실행 결과가 달라질 수 있으며, 당시 측정 근거는 위에 보존한 보고서다.
