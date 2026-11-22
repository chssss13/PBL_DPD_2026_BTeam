# FastGRNN DPD 모델

`v4.6_final`을 기준으로 GRU 셀을 FastGRNN 셀로 바꾸고, 입력·출력 선형층과 순환 경로에 파이프라인을 적용한 모델이다. 이전 작업의 최종 HLS 코드인 `v4.6_fastgrnn_outpipe`를 정리했다. 이 폴더의 모델 이름은 **FastGRNN**, HLS 최상위 함수와 RTL 모듈 이름은 `ResFastGRNN`이다.

FastGRNN 논문의 게이트·행렬 공유 구조를 적용했다. 논문의 저랭크 분해나 희소화는 적용하지 않았다. 기준 모델과 셀 구조 및 파라미터가 다르므로 v4.6의 GRU 파라미터를 그대로 사용할 수 없다.

## 폴더 구성

| 경로 | 내용 |
| --- | --- |
| `src/` | HLS C++ 소스. `res_fastgrnn.cpp`, `res_fastgrnn.h`가 최상위 구현과 인터페이스 |
| `final_rtl/` | 기존 HLS 합성에서 생성한 Verilog와 ROM 데이터. 최상위 `ResFastGRNN.v` |
| `tb/` | C 및 RTL 공동 시뮬레이션 테스트벤치. `fixtures/`는 테스트용 임의 파라미터 |
| `golden/` | 재학습으로 선택한 FastGRNN 파라미터 및 7,680개 시험 입력 |
| `reference/` | 저장된 HLS 고정소수점 및 학습 모델 시험 출력 |
| `training/` | PyTorch 모델·학습 코드, 체크포인트, 학습 조건과 결과 |
| `scripts/` | HLS 실행, 기존 합성 결과 공동 시뮬레이션, 파라미터 변환 도구 |
| `reports/` | 기존 HLS 합성, RTL 공동 시뮬레이션, Vivado 래퍼 합성 및 배치배선 보고서 |
| `parameter_contract.json` | 237개 파라미터의 이름, 배열 형태, 순서와 비트 폭 |

`final_rtl/`은 HLS가 생성한 RTL이며 Vivado에서 사용하는 블록 디자인 래퍼 전체는 포함하지 않는다. 합성·배치배선 보고서는 기존 `v4.6_fastgrnn_outpipe`에서 `bd_0_wrapper` 기준으로 수행한 결과다.

## 모델 구조

입력 I/Q로부터 `[I, Q, amplitude, amplitude³, Q/amplitude, I/amplitude]`의 6개 특성을 만들고, 6→5 입력 선형층과 PReLU, 5차원 FastGRNN 3개 층, 5→2 출력 선형층을 거쳐 I/Q를 출력한다. HLS 특성 계산과 활성화 함수는 고정소수점과 근사 테이블을 사용한다.

각 순환층의 개념적 계산은 다음과 같다. 실제 HLS에서는 고정소수점 양자화와 포화를 포함하여 식을 재배열해 계산한다.

```text
shared = W x_t + U h_(t-1)
z_t = sigmoid(shared + b_z)
n_t = tanh(shared + b_h)
h_t = (zeta * (1 - z_t) + nu) * n_t + z_t * h_(t-1)
layer_output = h_t + residual_gate * x_t
```

`h_t`를 다음 시점의 상태로 보관하고, 잔차가 더해진 `layer_output`을 다음 층에 전달한다. `zeta`, `nu`, `residual_gate`는 층별 스칼라이며 하드웨어에는 sigmoid를 적용한 0~1 값이 들어간다.

순환층마다 준비 연산 뒤에 상태 갱신과 명시적인 상태 레지스터를 배치한다. 입력 특성 뒤, 입력 선형층 MAC 뒤, 출력 선형층 MAC 뒤에도 레지스터 경계를 둔다. 이 구성의 기존 HLS 보고서에서 **샘플 루프 II는 2**, 루프 파이프라인 깊이는 16 cycle이다. 64개 샘플을 처리하는 최상위 호출의 간격과 샘플 II는 서로 다른 수치다.

## 인터페이스와 정밀도

- 64개 I/Q 샘플을 한 번에 처리하며, `segment_start`가 참인 호출의 첫 샘플에서 상태를 초기화한다. 제공된 시험 데이터는 2,560샘플마다 새 세그먼트다.
- 데이터와 편향은 `ap_fixed<15,3,AP_RND,AP_SAT>`, 가중치와 계수는 `ap_fixed<14,4,AP_RND,AP_SAT>`, 기본 누산 타입은 `ap_fixed<18,3,AP_RND,AP_SAT>`이다. 일부 선형층과 중간 계산은 별도 확장 타입을 사용한다.
- 학습 가능한 파라미터는 총 **237개**, 하드웨어 논리상 총 3,355비트다. 파일 순서는 `W_inj`, `b_inj`, `prelu`, `gating`, `W`, `U`, `b_z`, `b_h`, `zeta`, `nu`, `W_out`, `b_out`이며 배열은 행 우선 순서다.
- `golden/parameters.txt`는 학습 결과를 하드웨어에 전달하기 위한 텍스트 이미지다. 합성되는 별도의 파라미터 저장장치를 뜻하지 않으며, 테스트벤치가 읽어서 최상위 인자로 전달한다.

## 학습 및 정확도

`training/fastgrnn_model.py`는 동일한 샘플 단위 구조의 학습 모델이다. 본체는 float32이고 출력 선형층은 기존 재학습 코드의 양자화 인식 처리를 사용한다. 따라서 HLS 전체의 반올림·포화·활성화 근사를 비트 단위로 모사하는 모델은 아니다.

포함된 체크포인트는 기존 v4.6 출력을 교사로 하는 사전 학습 총 100 epoch 후 고정된 PA 모델을 통한 손실로 20 epoch 미세 조정한 결과다. 교사 학습은 30 epoch 체크포인트에서 이어갔으며 그때 Adam 상태는 새로 시작했다. 데이터는 `DPA_200MHz`, 세그먼트 길이 2,560, 배치 1 세그먼트, Adam 학습률 0.00025다. 선택된 PA 미세 조정 체크포인트는 20 epoch이며 자세한 조건과 이력은 `training/config.json`, `training/results.json`, `training/fastgrnn/history.json`을 참고한다.

| 시험 지표 | 학습 모델 본체 float32 + 출력층 양자화 | 학습 파라미터를 적용한 HLS C 시뮬레이션 |
| --- | ---: | ---: |
| PA 출력 NMSE | -12.21 dB | -12.39 dB |
| EVM | -14.01 dB | -14.08 dB |
| ACPR 좌 / 우 | -19.06 / -17.12 dBc | -19.18 / -17.14 dBc |

두 열 모두 시험 출력에 **학습된 PA 대리 모델**을 적용한 결과이며 실제 PA 측정 결과는 아니다. 이 학습 결과는 기존 v4.6의 약 -45.19 dB HLS 기반 PA 출력 NMSE보다 크게 낮은 정확도다. 따라서 이 폴더의 파라미터가 목표인 약 -40 dB 성능을 충족한다고 볼 수 없다.

`training/`의 파이썬 코드는 기존 `retraining/`의 관련 파일을 복사한 것이다. 이 위치에서도 같은 저장소의 `package/opendpd_min` 데이터와 PA·v4.6 체크포인트를 찾도록 `finetune_output_fc.py`의 저장소 루트 경로만 조정했다. 독립 실행 패키지는 아니며 Python 3.11, PyTorch, NumPy와 기존 `package/` 자산이 필요하다. 스크립트의 `--help` 실행을 확인했으며, 복사된 코드로 학습을 새로 수행하지는 않았다.

## 기존 합성 및 검증 결과

대상은 `xczu7ev-ffvc1156-2-e`, 목표 클록은 15 ns, 도구는 Vitis HLS / Vivado 2024.1이다.

| 항목 | 기존 결과 |
| --- | ---: |
| HLS 추정 클록 지연 | 13.047 ns |
| 샘플 루프 II | 2 cycle |
| RTL 공동 시뮬레이션 | Verilog PASS, 호출 지연 142~143 cycle |
| 래퍼 배치배선 후 LUT / FF | 16,134 / 10,113 |
| 래퍼 배치배선 후 DSP / BRAM | 244 / 7.5 |
| 배치배선 후 WNS / WHS | +1.165 ns / +0.029 ns |

RTL 공동 시뮬레이션은 `tb/fixtures`의 테스트용 임의 파라미터를 사용한 검증이다. 위 P&R은 이전에 수행한 결과를 보관한 것이며 `V5`에서 새로 수행한 것이 아니다. `reports/vivado_synthesis_comparison.json`은 별도의 **합성 단계** 비교이고, 내부의 `pnr_run: false`는 그 파일 작성 시점을 뜻한다. 배치배선 결과는 별도 `vivado_*routed.rpt`를 확인한다.

정리 과정에서 학습 파라미터와 시험 입력으로 C 시뮬레이션을 다시 실행했다. 테스트벤치의 선형층·셀·상태 이어쓰기 검사가 통과했고, 7,680개 샘플 출력은 `reference/hls_test_out.txt`와 SHA-256 기준 완전히 일치했다. 실행 당시 임시 폴더 이름이 `fastGRNN`이어서 로그에는 해당 경로가 남아 있다. 학습 파라미터를 사용한 RTL 공동 시뮬레이션이나 새 P&R은 수행하지 않았다.

## 실행 방법

저장소 루트의 PowerShell에서 실행한다. Vitis HLS 2024.1 경로는 설치 위치에 맞춘다. 각 실행은 기존 폴더 덮어쓰기를 거부하므로 재실행 시 새 `RUN_NAME`을 지정한다.

```powershell
# 학습 파라미터와 7,680개 시험 샘플로 C 시뮬레이션
$env:RUN_NAME = 'trained_check02'
& 'C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat' -f V5/scripts/run_trained_csim.tcl
Get-FileHash V5/build/trained_check02/trained_hls_out.txt, V5/reference/hls_test_out.txt

# 별도의 신규 HLS 합성: 기본 테스트벤치 실행 후 csynth
$env:RUN_NAME = 'synth02'
$env:MODE = 'csynth'
Remove-Item Env:TB_ARGS -ErrorAction SilentlyContinue
& 'C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat' -f V5/scripts/run_hls.tcl

# 위에서 합성을 완료한 동일 RUN_NAME의 솔루션으로 C/RTL 공동 시뮬레이션
& 'C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat' -f V5/scripts/verify_existing.tcl
```

`run_hls.tcl`은 기본적으로 C 시뮬레이션만 수행한다. 합성과 공동 시뮬레이션은 배치배선을 실행하지 않는다. 파라미터 JSON을 텍스트 입력으로 변환하려면 `python V5/scripts/pack_parameters.py --input V5/golden/parameters_hardware.json --out <새 파일>`을 사용한다. `tb/fixtures/`는 인터페이스 회귀용으로, 학습된 `golden/`과 혼동하지 않아야 한다.
