# FastGRNN 최종 모델

v4.7의 GRU 3개 층을 모두 FastGRNN으로 교체한 모델이다. 이전 V5 전체 FastGRNN에 대해 W·U 가중치 전달 경로를 한 단계 단축한 RTL을 최종본으로 정리했다. 최상위 함수와 RTL 모듈은 `ResFastGRNN`이다.

v4.7의 원래 최적화는 2층 GRU 가중치 전달 경로에 적용되어 있었다. 세 층을 모두 FastGRNN으로 교체하면서 해당 GRU 경로는 없어지므로, 본 최종본에서는 FastGRNN의 W·U 전달 경로를 별도로 최적화했다. `src/`는 **RTL 후처리 전 HLS 소스**, `final_rtl/`은 후처리를 적용하고 검증·배치배선한 최종 RTL이다. HLS를 다시 합성하는 것만으로는 우회가 자동으로 적용되지 않는다.

## 구성

| 경로 | 내용 |
| --- | --- |
| `src/` | 3층 FastGRNN HLS 소스. 특성 추출 및 입력·출력 선형층 파이프라인 포함 |
| `final_rtl/` | W·U 전달 경로를 한 단계 단축한 최종 Verilog 및 ROM 데이터 |
| `tb/` | HLS 테스트벤치와 테스트용 임의 가중치·입력 |
| `golden/` | 기존 학습으로 선택한 237개 파라미터와 7,680샘플 시험 입력 |
| `reference/rtl_test_out.txt` | 최종 RTL에 학습 가중치를 적용한 7,680샘플 출력 |
| `training/` | 기존 학습의 체크포인트, 설정, 결과 및 이력 |
| `reports/` | 래퍼 배치배선, C/RTL 공동 시뮬레이션, 정확도 및 비교 결과 |
| `scripts/` | HLS 실행, RTL 경로 변경, 파라미터 패킹 및 래퍼 배치배선 스크립트 |
| `parameter_contract.json` | 237개 파라미터의 순서와 정밀도 |

## 모델과 가중치 경로

I/Q에서 6개 특성 `[I, Q, amplitude, amplitude³, Q/amplitude, I/amplitude]`를 추출하고, 6→5 입력 선형층과 PReLU, hidden size 5의 FastGRNN 3개 층, 5→2 출력 선형층을 거친다. FastGRNN 한 층은 다음과 같이 입력·순환 선형 연산을 공유한다.

```text
shared = W x_t + U h_(t-1)
z_t = sigmoid(shared + b_z)
n_t = tanh(shared + b_h)
h_t = (zeta * (1 - z_t) + nu) * n_t + z_t * h_(t-1)
layer_output = h_t + residual_gate * x_t
```

실제 HLS는 각 단계의 고정소수점 반올림·포화와 활성화 근사를 포함한다. 다음 시점의 상태는 잔차를 더하기 전 `h_t`다. 데이터와 편향은 `ap_fixed<15,3,AP_RND,AP_SAT>`, 가중치는 `ap_fixed<14,4,AP_RND,AP_SAT>`이다. 샘플 루프 II는 2이고 최상위 함수는 한 호출에서 64샘플을 처리한다. `segment_start`는 호출 첫 샘플에서 상태를 초기화한다.

세 층의 W·U 행렬은 각각 5×5로 총 150개 가중치다. 각 전달 경로에서 마지막 지연 단계 하나를 우회했다. 최초 레지스터까지 직접 연결하는 후보는 호출 사이 가중치를 바꾸는 시험에서 실패했으므로 최종본에 사용하지 않았다. 변경은 `final_rtl/ResFastGRNN_Loop_LOOP_T_proc.v`의 FastGRNN 준비 단계 입력 연결에만 적용됐다.

## 래퍼 배치배선

동일한 `xczu7ev-ffvc1156-2-e`, 15 ns, Vivado 2024.1, `bd_0_wrapper`, IP 합성 `AreaOptimized_high` 조건이다.

| 항목 | 이전 V5 전체 FastGRNN | 최종본 | 변화 |
| --- | ---: | ---: | ---: |
| LUT | 16,134 | 16,134 | 0 |
| FF | 10,113 | 8,625 | -1,488 (-14.7%) |
| 시프트 레지스터 LUT | 724 | 731 | +7 |
| DSP | 244 | 244 | 0 |
| BRAM 타일 | 7.5 | 7.5 | 0 |
| WNS | +1.165 ns | +1.115 ns | -0.050 ns |
| WHS | +0.029 ns | +0.029 ns | 0 |

최종본은 TNS 0, 배선 오류 0이다. v4.7 기준 자원은 LUT 20,069, FF 19,200, DSP 347, BRAM 7.5, WNS +0.051 ns이나, V5는 전체 셀 구조와 선형층 파이프라인도 바뀌었으므로 W·U 우회만의 효과로 비교하면 안 된다.

## 검증과 정확도

- 학습된 237개 파라미터와 7,680샘플을 최종 RTL로 C/RTL 공동 시뮬레이션해 PASS했다. 2,560샘플마다 상태를 초기화했고, I/Q 출력 15,360개는 기존 C 시뮬레이션 출력과 완전히 일치했다.
- 추가로 6회 연속 호출에서 호출 간 W·U 변경, 상태 이어쓰기와 리셋을 검증했다. 공동 시뮬레이션 RTL, 배치배선에 패키징된 RTL 및 `final_rtl/`의 변경 파일은 SHA-256이 일치한다. 관련 정보는 `reports/full_verification.json`과 `reports/verified_candidate.json`에 있다.
- 동일한 PA **대리 모델**로 평가한 최종 RTL 출력은 NMSE **-12.3876 dB**, EVM **-14.0797 dB**, ACPR 좌 **-19.1779 dBc**, 우 **-17.1420 dBc**다. 우회 전 결과와 동일하다. 실제 PA 측정은 아니다.
- 같은 조건에서 DPD 없이 평가한 NMSE는 -11.0676 dB다. 이 모델의 정확도는 v4.7의 기존 DPD보다 크게 낮다.

기존 학습은 v4.6 출력을 교사로 100 epoch, PA 대리 모델을 고정한 미세 조정 20 epoch을 사용했다. 교사 학습 30 epoch 이후 이어서 학습하는 시점에 Adam 상태를 새로 시작했다. 학습 코드는 상위 `V5/training/`에 있고 이 폴더는 선택된 체크포인트와 기록을 보관한다.

## 재실행 시 주의

`scripts/run_hls.tcl`은 후처리 전 소스를 C 시뮬레이션하고 `MODE=csynth`일 때 HLS 합성한다. 합성 결과에 우회를 다시 적용하려면 새 출력 경로를 지정해 다음 명령을 사용한다.

```powershell
python V5/final/scripts/patch_weight_paths.py --input <HLS_생성_verilog_폴더> --out <새_RTL_폴더>
```

패턴과 신호 수가 맞지 않으면 중단한다. 패턴이 맞더라도 호출 간 가중치 변경과 상태 이어쓰기를 포함해 C/RTL 공동 시뮬레이션을 다시 수행해야 한다. `scripts/wrapper_pnr.tcl`은 이 폴더의 `final_rtl/`을 사용해 새로운 래퍼 프로젝트를 만들며 기존 `wrapper_pnr/`를 덮어쓰지 않는다. 학습 가중치는 `golden/parameters.txt`이고 `tb/fixtures/`는 성능 평가용이 아닌 임의 회귀 테스트다.
