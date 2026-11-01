# v2.3 — 자료형 축소와 256구간 선형 보간

**한 줄 요약:** 정확도와 HLS II=2를 유지하면서 data·weight 비트와 활성화 표를 줄여 배선 후 주기를 18.105 ns로 단축했지만, 15 ns 목표는 미달했다.

2026-11-01. [전체 결과 비교](../README.md)와 [v2 개요](../../README.md)를 참고한다.

## 의사결정과 변경 과정

1. v2.2를 기준으로 data `16,3 → 15,3`, weight `16,4 → 14,4`를 실험했다. accum `18,3`과 FEx inverse `16,8`은 유지했다.
2. sigmoid·tanh의 선형 보간을 512구간에서 256구간으로 축소했다. 입력 범위는 `[-4,4)`, 구간 폭은 `1/32`, 경계점은 함수마다 257개다. 실행용 표에는 256구간의 시작값과 차이를 저장한다.
3. `r * (W_hn_h + b_hn)`의 덧셈 결과만 곱셈 전에 `ap_fixed<16,4,AP_RND,AP_SAT>`로 반올림·포화하도록 했다. 입력 7,680샘플, 3층·5개 상태의 총 115,200개 관측 중 해당 중간값의 포화는 0회였다. 이 수치는 해당 테스트 벡터에 한정된다.
4. 결합 조건을 Python으로 검증한 뒤 C++에 반영했다. sigmoid와 tanh 각각 Q3.12 입력 32,768개를 검사했고, C-sim 출력도 Python과 정수값 기준으로 일치했다.
5. HLS 합성과 별도 Vivado 배치·배선을 완료했다. 여러 변경을 동시에 적용했으므로 각 변경의 개별 기여는 분리되지 않는다.

## 기준과 결과

| 지표 | 기준 | v2.3 | 판정 |
|---|---:|---:|---|
| PA NMSE | ≤ -43.48 dB | -45.11 dB | 통과 |
| PA ACPR L | ≤ -50.39 dBc | -53.02 dBc | 통과 |
| PA ACPR R | ≤ -47.83 dBc | -49.87 dBc | 통과 |
| HLS LOOP_T II | 2 | 2 | HLS 기준 달성 |
| 배선 후 주기 | ≤ 15 ns | 18.105 ns | 미달 |
| 배선 후 WNS | ≥ 0 ns | -3.105 ns | 미달 |

PA EVM은 -48.89 dB다. 정확도는 7,680샘플 C-sim 출력을 제공된 PA 모델로 평가한 결과다. Python과 C-sim의 Q3.12 정수 출력 불일치는 0개다. RTL co-sim과 보드 실측은 수행하지 않았다.

## v2.2와 비교

| 항목 | v2.2 | v2.3 |
|---|---:|---:|
| PA NMSE (dB) | -45.48 | -45.11 |
| PA EVM (dB) | -49.35 | -48.89 |
| PA ACPR L / R (dBc) | -53.44 / -50.30 | -53.02 / -49.87 |
| HLS LOOP_T II | 2 | 2 |
| HLS 예상 주기 (ns) | 13.942 | 13.924 |
| HLS LUT / FF / DSP | 269,332 / 139,826 / 564 | 239,177 / 135,681 / 564 |
| Vivado 합성 후 주기 (ns) | 16.590 | 17.299 |
| 배선 후 주기 (ns) | 18.649 | 18.105 |
| 배선 후 WNS (ns) | -3.649 | -3.105 |
| 배선 후 LUT / FF / DSP / BRAM | 58,319 / 48,897 / 564 / 0 | 56,671 / 43,367 / 305 / 0 |

배선 후 주기는 0.544 ns 짧아졌고 LUT 1,648개, FF 5,530개, DSP 259개가 줄었다. HLS 수치와 배치·배선 후 수치는 서로 다른 단계다.

## 최종 하드웨어 사용량

| 자원 | Vivado 배치·배선 후 | FPGA 전체 대비 |
|---|---:|---:|
| LUT | 56,671 | 24.60% |
| FF | 43,367 | 9.41% |
| DSP | 305 | 17.65% |
| BRAM | 0 | 0% |

## 검증 조건과 근거

- Vitis HLS / Vivado 2024.1, `xczu7ev-ffvc1156-2-e`, 목표 15 ns, HLS uncertainty 1 ns, DSP full reg false, LOOP_T II=2 요청, Vivado 최대 6스레드 설정.
- H=5, GRU 3층, TIME_STEP=64, 2,560샘플마다 상태 초기화. P&R은 IP의 out-of-context 구현이며 시스템 외부 I/O 지연은 별도 검증이 필요하다.
- [정확도 평가](accuracy/c_evaluation.txt), [Python–C++ 비교](accuracy/compare.json), [HLS 합성](reports/hls/ResGRU_csynth.rpt), [LOOP_T](reports/hls/Loop_LOOP_T_proc_csynth.rpt).
- [최종 요약](reports/implementation/ResGRU_export.rpt), [배선 후 타이밍 경로](reports/implementation/timing_summary_routed.rpt), [자원](reports/implementation/utilization_routed.rpt), [배선 상태](reports/implementation/route_status.rpt).
- 실행 로그는 `logs/`, 실험 당시 소스·테스트벤치는 `source/`, 해시는 `manifest.sha256.json`에 있다. 로그의 절대 경로는 실행 당시 경로다.

## 재현

`v2/`에서 실행한다. Python 의존성과 Vitis HLS 환경은 별도로 준비해야 한다. 기존 재현 프로젝트가 있으면 덮어쓰지 않고 중단한다.

```powershell
python result/v2.3/source/evaluate.py
$env:STEPS='csim csynth'
vitis_hls -f result/v2.3/source/reproduce.tcl
```

P&R까지 재현하려면 `STEPS='csim csynth impl'`로 지정한다. 독립 프로젝트는 `package/prj_replay_v2_3_run`에 생성된다. v2.3 C++을 다른 스크립트로 사용할 때는 `ACT_LUT=3`을 지정해야 한다.
