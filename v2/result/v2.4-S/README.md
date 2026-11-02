# v2.4-S — sehyeon v1 기반 보간과 recurrent 게이트 분리

**기준 버전:** 원본 sehyeon v1에서 분기한 독립 후보다. v2.3의 소스를 이어서 수정한 버전은 아니다. 파일 위치가 `v2/`인 것은 2주차 실험을 함께 관리하기 위해서다. 여기서 S는 sehyeon을 뜻한다.

2026-11-02. 기존 실험 `v1_interp_narrow_recurrent_gate_split0_csynth`의 소스와 결과를 v2.4-S로 보관한다. 15 ns 조건에서 정확도와 HLS II=2는 충족했지만 **배치·배선 후 타이밍은 미달**했다.

## 구현 조건과 v2.3의 차이

| 항목 | v2.3 | v2.4-S |
|---|---|---|
| 출발점 | hyeonseo v1.7 기반 v2.2 | 원본 sehyeon v1 |
| 구조와 자료형 | H=5, L=3, data 15,3 / weight 14,4 / accum 18,3 | 동일 |
| sigmoid·tanh | 각각 `[-4,4)` 256구간 선형 보간, `ACT_LUT=3` | 각각 `[-4,4)` 256구간 선형 보간 |
| FEx | 제곱근·역수 기반, inverse 16,8 | Newton–Raphson 4회, inverse 16,6 |
| GRU 행렬곱 누산 | 5항 adder tree, 각 노드에서 누산 타입 변환 | 원본 순차 누산 |
| recurrent 합과 bias | `W_hn_h + b_hn`을 16,4로 변환한 뒤 r과 곱함 | 중간 16,4 변환 없이 r과 곱함 |
| recurrent 곱셈 구현 | GRU tree 방식 | r/z/n별 곱셈 함수를 구분하고 DSP latency 0을 요청 |

두 버전은 각각의 원본과 수치 처리 방식이 다르므로 수치나 자원 차이를 한 변경만의 효과로 해석할 수 없다. 게이트별 함수를 분리했어도 같은 게이트 안의 연산 공유는 남을 수 있다.

## 정확도와 HLS

두 후보의 C-sim 출력 7,680개를 같은 PA 모델에 넣어 평가했다. 상태는 2,560샘플마다 초기화한다. 아래 PA 수치는 작을수록 좋다.

| 항목 | 기준 | v2.3 | v2.4-S |
|---|---:|---:|---:|
| NMSE (dB) | ≤ -43.48 | -45.11 | -44.97 |
| EVM (dB) | 참고 | -48.89 | -48.75 |
| ACPR L (dBc) | ≤ -50.39 | -53.02 | -53.35 |
| ACPR R (dBc) | ≤ -47.83 | -49.87 | -50.08 |
| HLS LOOP_T II | 2 | 2 | 2 |
| HLS 추정 주기 (ns) | 참고 | 13.924 | 13.840 |
| HLS LUT / FF / DSP | 추정 | 239,177 / 135,681 / 564 | 231,211 / 128,096 / 475 |

v2.4-S의 C-sim 출력은 Python 참조와 Q3.12 기준 전부 일치한다. PA 정확도는 C-sim과 Python의 일치 여부와 별도로 평가했다. 평가 범위는 해당 입력과 PA 모델에 한정된다. RTL co-sim과 보드 실측은 수행하지 않았다.

## 배치·배선 후 타이밍과 자원

두 결과 모두 Vitis HLS / Vivado 2024.1, `xczu7ev-ffvc1156-2-e`, 15 ns 클록 조건에서 구현했다. 숫자는 Vivado P&R 결과이며 HLS 추정 자원과 구분한다. 주기는 15 ns 제약과 WNS에서 환산했다.

| 항목 | v2.3 | v2.4-S | 차이 (S − v2.3) |
|---|---:|---:|---:|
| 배선 후 WNS (ns) | -3.105 | -2.524 | +0.581 |
| 환산 주기 (ns) | 18.105 | 17.524 | -0.581 |
| LUT | 56,671 | 47,575 | -9,096 |
| FF | 43,367 | 41,799 | -1,568 |
| DSP | 305 | 333 | +28 |
| CLB | 11,717 | 10,039 | -1,678 |
| BRAM / URAM | 0 / 0 | 0 / 0 | 0 / 0 |

v2.4-S는 v2.3보다 LUT가 약 16.1% 적고 DSP는 약 9.2% 많다. WNS는 0.581 ns 개선됐지만 15 ns 제약에서 여전히 2.524 ns 부족하다. v2.4-S의 WHS는 +0.037 ns이고 라우팅 오류는 0이다. 이 구현은 IP 중심의 구현 결과이며 시스템 외부 I/O 타이밍과 실제 보드 동작은 별도 검증이 필요하다.

## 근거와 재현

- [v2.3과 동일 PA 모델로 C-sim 출력 비교](accuracy/c_evaluation.txt), [C-sim 일치](accuracy/csim_comparison.json).
- [HLS 요약](reports/hls/ResGRU_csynth.rpt), [LOOP_T](reports/hls/Loop_LOOP_T_proc_csynth.rpt), [HLS 로그](logs/csynth.log).
- [P&R 요약](reports/implementation/ResGRU_export.rpt), [타이밍](reports/implementation/timing_summary.rpt), [자원](reports/implementation/utilization.rpt), [최악 경로 100개](reports/implementation/setup_paths100.rpt), [배선 상태](reports/implementation/route_status.rpt).
- [실험 당시 소스](source/src/), [테스트벤치](source/tb/), [게이트 분리 변경 내역](source/recurrent_gate_split.diff), [설정](settings.json). 로그와 보고서의 절대 경로는 실행 당시 환경이다.

재현하려면 Vitis HLS 2024.1과 Python/numpy 환경을 준비한 뒤 저장소에서 다음을 실행한다. 독립 프로젝트 `v2/package/prj_replay_v24s`가 이미 있으면 덮어쓰지 않고 중단한다. C-sim 및 csynth를 실행하며 `V24S_IMPL=1`을 지정할 때만 P&R을 추가한다.

```powershell
vitis_hls -f v2/result/v2.4-S/source/reproduce.tcl
# P&R도 실행하려면 별도의 새 프로젝트에 대해 $env:V24S_IMPL='1' 설정
```

곱셈 wide·누산 wide와 sigmoid 64구간 후보는 후속 실험이며, 이 v2.4-S 결과에 포함되지 않는다.
