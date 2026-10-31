# v2.1 — 누산기·상태 갱신·GRU adder tree

**한 줄 요약:** 누산기를 줄이고 GRU 연산 구조를 변경해 정확도와 HLS II=2를 확인했으나, 배선 후 21.287 ns로 15 ns 목표는 미달했다.

2026-11-01. 기준 코드 출처와 공통 조건은 [v2 개요](../../README.md), 전체 비교는 [결과 목록](../README.md)에 기록했다.

## 의사결정과 변경 과정

1. `hyeonseo` 브랜치의 v1.7 시점 고정 커밋을 출발점으로 사용했다. `sehyeon` 브랜치의 기존 v1과는 별도 코드 기반이다.
2. 누산기를 `32,12 → 18,3`으로 줄였다. data `16,3`, weight `16,4`는 유지했다.
3. 상태 갱신을 `(1-z)*n + z*h_prev`에서 `n + z*(h_prev-n)`으로 정리했다. 수학적으로 동등하지만 고정소수점 연산의 중간 정밀도에 따라 차이가 날 수 있으므로 C-sim으로 확인했다.
4. GRU의 입력·은닉 상태 행렬곱 6곳에 5항 adder tree를 적용했다. 각 곱과 각 합에서 accum_t로 양자화한다. 입력·출력 FC는 기존 순차 누산을 유지했다.
5. 이번 7,680샘플에서는 상태 갱신 변경 및 tree 적용 전후 출력이 같았다. 모든 입력에 대한 동등성을 증명한 것은 아니다. 비교 파일은 `accuracy/compare_previous_*.txt`에 있다.
6. C-sim과 csynth 후 기존 RTL을 Vivado에서 합성·배치·배선했다. 여러 변경을 합친 결과라 기준 v1.7 코드와의 차이를 한 변경만의 효과라고 해석하지 않는다.

활성화 함수는 함수당 4,096개 direct LUT(`ACT_LUT=2`, `DIRECT_LUT_SHIFT=4`)를 유지했다. FEx는 제공 코드의 고정소수점 중간값 및 double sqrt/역수 계산, 역수 `16,8`을 유지했다.

## 기준과 결과

| 지표 | 통과 기준 | 결과 | 판정 |
|---|---:|---:|---|
| PA NMSE | ≤ -43.48 dB | -43.66 dB | 통과 |
| PA ACPR L | ≤ -50.39 dBc | -51.92 dBc | 통과 |
| PA ACPR R | ≤ -47.83 dBc | -48.52 dBc | 통과 |
| HLS LOOP_T II | 2 | 2 | HLS 기준 달성 |
| 배선 후 클록 주기 | ≤ 15 ns | 21.287 ns | 미달 |
| 배선 후 WNS | ≥ 0 ns | -6.287 ns | 미달 |

EVM은 -47.72 dB다. PA 지표는 **C-sim 출력**을 제공된 PA 모델에 통과시킨 결과다. C-sim 7,680샘플 오류 0, Python 비교 PASS(허용 NMSE -60 dB)를 확인했다. 비교 파일의 작은 오차는 텍스트 출력 정밀도에 따른 차이다. **이 버전의 RTL co-sim은 수행하지 않았고 보드 실측도 하지 않았다.** 구현 정상 종료와 15 ns 타이밍 통과는 구분한다.

## HLS 합성 추정치

| 추정 주기 | LUT | FF | DSP | BRAM_18K | LOOP_T II |
|---:|---:|---:|---:|---:|---:|
| 13.789 ns | 266,748 | 140,136 | 636 | 0 | 2 |

HLS 추정 자원과 아래 실제 배치·배선 결과는 서로 다른 단계의 수치다.

## 최종 하드웨어 사용량

| 자원 | Vivado 배치·배선 후 |
|---|---:|
| LUT | 70,412 |
| FF | 48,482 |
| DSP | 636 |
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
python result/v2.1/source/evaluate.py
$env:STEPS='csim csynth'
vitis_hls -f result/v2.1/source/reproduce.tcl
```

처음부터 P&R까지 재현하려면 실행 전에 `STEPS='csim csynth impl'`로 지정한다. 재현 프로젝트 `package/prj_replay_v2_2`가 이미 있으면 덮어쓰지 않고 중단한다. 원래 실행 파일은 `source/scripts/original_run_resgru.tcl`에 보존했으며 재현용 진입점은 상대 경로를 사용하도록 별도로 작성했다.
