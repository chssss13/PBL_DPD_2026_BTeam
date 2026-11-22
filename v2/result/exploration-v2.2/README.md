# v2.2 — 활성화 함수 선형 보간

**한 줄 요약:** sigmoid·tanh를 512구간 선형 보간으로 변경해 정확도를 개선하고 배선 후 주기를 18.649 ns로 단축했으나, 15 ns 목표는 미달했다.

2026-11-01. 기준 코드 출처와 공통 조건은 [v2 개요](../../README.md), 전체 비교는 [결과 목록](../README.md)에 기록했다.

## 의사결정과 변경 과정

1. v2.1의 GRU 구조·자료형·FEx·초기화 조건을 유지하고 활성화 함수의 조회 방식을 변경했다.
2. sigmoid와 tanh의 입력 범위 `[-4,4)`를 각각 512개 구간으로 나눴다. 구간 폭은 `1/64`이며 513개 경계점에서 함숫값을 계산한다.
3. 각 구간에 시작 함수값 B와 다음 경계점까지의 차이 D를 저장하고 `y = B + αD`로 보간했다. 따라서 실행용 표는 함수당 512개 항목이다.
4. Q3.13 입력의 부호 비트를 반전한 후 상위 9비트로 구간, 하위 7비트로 구간 내 위치를 선택한다. 정수 연산으로 `B + ((D*fraction + 64) >> 7)`을 계산한다. sigmoid 항목은 22비트, tanh는 24비트이며 보간 곱셈은 fabric으로 지정했다. 0클록 지연 요청과 완전 분할은 유지했다.
5. Python으로 PA 정확도를 확인한 뒤 C++에 적용했다. 두 함수 각각 65,536개 입력에 대한 정수 조회·보간 검사를 통과했고, 전체 GRU C-sim 출력은 Python과 Q3.13 정수값 기준으로 일치했다.
6. csynth에서 II=2를 확인한 뒤 기존 RTL로 Vivado 합성·배치·배선을 실행했다. 표 축소에 보간 연산 비용이 추가되지만 이번 결과에서는 LUT·DSP와 배선 후 주기가 함께 개선됐다.

이번 버전은 `data 16,3 / weight 16,4 / accum 18,3`, 보간 512구간(`ACT_LUT=3`)이다. 이후 후보는 이 보고서에 포함하지 않는다.

## 기준과 결과

| 지표 | 통과 기준 | 결과 | 판정 |
|---|---:|---:|---|
| PA NMSE | ≤ -43.48 dB | -45.48 dB | 통과 |
| PA ACPR L | ≤ -50.39 dBc | -53.44 dBc | 통과 |
| PA ACPR R | ≤ -47.83 dBc | -50.30 dBc | 통과 |
| HLS LOOP_T II | 2 | 2 | HLS 기준 달성 |
| 배선 후 클록 주기 | ≤ 15 ns | 18.649 ns | 미달 |
| 배선 후 WNS | ≥ 0 ns | -3.649 ns | 미달 |

EVM은 -49.35 dB다. PA 지표는 **C-sim 출력**을 제공된 PA 모델에 통과시킨 결과다. C-sim 7,680샘플 오류 0, Python 비교 PASS(허용 NMSE -60 dB)를 확인했다. 비교 파일의 작은 오차는 텍스트 출력 정밀도에 따른 차이다. **이 버전의 RTL co-sim은 수행하지 않았고 보드 실측도 하지 않았다.** 구현 정상 종료와 15 ns 타이밍 통과는 구분한다.

## HLS 합성 추정치

| 추정 주기 | LUT | FF | DSP | BRAM_18K | LOOP_T II |
|---:|---:|---:|---:|---:|---:|
| 13.942 ns | 269,332 | 139,826 | 564 | 0 | 2 |

HLS 추정 자원과 아래 실제 배치·배선 결과는 서로 다른 단계의 수치다.

## v2.1과 비교

| 항목 | v2.1 | v2.2 |
|---|---:|---:|
| PA NMSE (dB) | -43.66 | -45.48 |
| PA EVM (dB) | -47.72 | -49.35 |
| PA ACPR L / R (dBc) | -51.92 / -48.52 | -53.44 / -50.30 |
| HLS 추정 주기 (ns) | 13.789 | 13.942 |
| Vivado 합성 후 주기 (ns) | 16.823 | 16.590 |
| 배선 후 주기 (ns) | 21.287 | 18.649 |
| 배선 후 LUT / FF / DSP | 70,412 / 48,482 / 636 | 58,319 / 48,897 / 564 |

배선 후 주기는 2.638 ns 단축됐고 LUT는 12,093개, DSP는 72개 감소했다. FF는 415개 증가했다. HLS 추정 주기는 소폭 늘었지만 실제 배선 후 주기는 개선됐다. `sehyeon` 브랜치의 기존 v1 결과인 17.506 ns보다는 아직 1.143 ns 느리며, v1과는 FEx 등 여러 조건이 달라 단일 원인 비교는 아니다.

## 최종 하드웨어 사용량

| 자원 | Vivado 배치·배선 후 |
|---|---:|
| LUT | 58,319 |
| FF | 48,897 |
| DSP | 564 |
| BRAM | 0 |

## 검증 조건과 근거 파일

- Vitis HLS / Vivado 2024.1, `xczu7ev-ffvc1156-2-e`, 목표 15 ns, HLS uncertainty 1 ns, DSP full reg false, LOOP_T II=2 요청.
- H=5, GRU 3층, TIME_STEP=64, 상태 초기화 2,560샘플, 전체 7,680샘플. data `16,3`, weight `16,4`, accum `18,3`, FEx inverse `16,8`.
- `export_design -flow impl -format ip_catalog`. Vivado synth/impl strategy는 default, synth_design directive는 `sdx_optimization_effort_high`, phys_opt는 auto로 보고됐다. 세부 옵션은 [export_impl.rpt](reports/implementation/export_impl.rpt)에 보존한다. 구현 로그에 최대 6스레드 설정이 확인된다.
- P&R은 독립 RTL의 out-of-context 구현이다. 시스템 외부 I/O 지연을 포함한 보드 전체의 타이밍 보장은 아니며 시스템 통합 시 별도 제약 검증이 필요하다.
- [정확도 평가](accuracy/c_evaluation.txt), [Python–C++ 비교](accuracy/compare.txt), [HLS 합성](reports/hls/ResGRU_csynth.rpt), [LOOP_T](reports/hls/Loop_LOOP_T_proc_csynth.rpt).
- [최종 요약](reports/implementation/ResGRU_export.rpt), [배선 후 타이밍 경로](reports/implementation/timing_summary_routed.rpt), [배선 상태](reports/implementation/route_status.rpt).
- 실행 로그는 `logs/`, 검증 당시 코드·TB는 `source/`, 파일 해시는 `manifest.sha256.json`에 있다. 원본 로그의 절대 경로는 실행 당시 경로다.

## 재현

아래 명령은 `v2/`에서 실행한다. Python 의존성 및 Vitis HLS 실행 환경은 별도로 준비해야 한다. 기록된 소스를 사용하는 재현용 스크립트를 제공하며, 과거 보고서나 기존 합성 프로젝트는 덮어쓰지 않는다.

```powershell
python result/v2.2/source/evaluate.py
$env:STEPS='csim csynth'
vitis_hls -f result/v2.2/source/reproduce.tcl
```

처음부터 P&R까지 재현하려면 실행 전에 `STEPS='csim csynth impl'`로 지정한다. 재현 프로젝트 `package/prj_replay_v2_2`가 이미 있으면 덮어쓰지 않고 중단한다. 원래 실행 파일은 `source/scripts/original_run_resgru.tcl`에 보존했으며 재현용 진입점은 상대 경로를 사용하도록 별도로 작성했다.
