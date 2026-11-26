# v5-5 · 3층 bias-only 혼합 모델

**현재 채택본은 1·2층에 v5-1의 입력 기반 게이트를, 3층에 v5-3의 bias-only 게이트를 적용한 혼합 모델이다.** 고정소수점 평가에서 NMSE −43.89 dB, 좌·우 ACPR −50.91 / −48.91 dBc로 정확도 기준을 통과했다. 샘플 루프 II는 2이며 배선 후 WNS는 15 ns 기준 +0.515 ns다.

## 모델과 재학습

| GRU 층 | reset·update 게이트 | 후보 상태 |
|---|---|---|
| 1·2층 | 현재 층 입력과 bias로 계산하는 [v5-1 방식](../v5-1/README.md) | 현재 층 입력, 이전 은닉 상태, reset 게이트 사용 |
| 3층 | 학습된 bias로 계산하는 [v5-3 방식](../v5-3/README.md) | 현재 층 입력, 이전 은닉 상태, reset 게이트 사용 |

### 층별 GRU 수식과 논문 출처

v5-5는 **두 논문의 게이트 설계를 층별로 조합한 LW-ResGRU**다. 1·2층은 Gang Li 외의 IGRNN에서 현재 입력으로 게이트를 계산하는 방식을, 3층은 Rahul Dey와 Fathi M. Salem의 GRU3에서 bias만으로 게이트를 계산하는 방식을 가져왔다.

$x_t^{(\ell)}$은 시점 $t$의 $\ell$층 입력, $h_{t-1}^{(\ell)}$은 같은 층의 직전 은닉 상태다. $r$은 reset 게이트, $z$는 update 게이트이며, $\odot$은 원소별 곱이다. 각 층에서 게이트의 입력 bias와 순환 bias를 미리 더해 $b_r=b_{ir}+b_{hr}$, $b_z=b_{iz}+b_{hz}$로 사용한다.

**1·2층 · 현재 입력 기반 게이트**

$$
\begin{aligned}
r_t^{(\ell)} &= \sigma\!\left(W_{ir}^{(\ell)} x_t^{(\ell)} + b_r^{(\ell)}\right), \\
z_t^{(\ell)} &= \sigma\!\left(W_{iz}^{(\ell)} x_t^{(\ell)} + b_z^{(\ell)}\right),
\qquad \ell \in \{1,2\}.
\end{aligned}
$$

두 게이트는 현재 층 입력에 따라 달라진다. 게이트 계산에서 순환 행렬곱 $W_{hr}h_{t-1}$와 $W_{hz}h_{t-1}$를 생략한다. [Instant Gated Recurrent Neural Network Behavioral Model for Digital Predistortion of RF Power Amplifiers, IEEE Access, 2020](https://doi.org/10.1109/ACCESS.2020.2986816)

**3층 · bias-only 게이트**

$$
\begin{aligned}
r_t^{(3)} &= \sigma\!\left(b_r^{(3)}\right), \\
z_t^{(3)} &= \sigma\!\left(b_z^{(3)}\right).
\end{aligned}
$$

같은 bias를 쓰는 동안 두 게이트는 샘플이 바뀌어도 일정하다. 게이트 계산에서 입력 행렬곱과 순환 행렬곱을 모두 생략한다. [Gate-Variants of Gated Recurrent Unit (GRU) Neural Networks, IEEE MWSCAS, 2017](https://ieeexplore.ieee.org/document/8053243)

**세 층 공통 · 후보 상태와 은닉 상태 갱신**

아래 식에서는 층 표시를 생략했다. 이전 은닉 상태는 후보 상태 $n_t$와 새 은닉 상태 $h_t$를 계산할 때 쓰인다. HLS에서는 sigmoid와 tanh에 구간별 선형 근사를 적용하고, 중간값과 출력에 고정소수점 자료형을 사용한다. [후보 상태와 상태 갱신 코드](src/gru_cell.h#L305) · [층별 호출과 bias 합산 코드](src/multi_gru.cpp#L373)

$$
\begin{aligned}
n_t &= \tanh\!\left(W_{in}x_t+b_{in}+r_t\odot(W_{hn}h_{t-1}+b_{hn})\right), \\
h_t &= n_t + z_t \odot (h_{t-1}-n_t).
\end{aligned}
$$

### 재학습

배포된 원본 DPD 체크포인트 `DPD_S_4574_M_RGRUWFEX_H_5_F_50_P_591_D_0_R_2.pt`에서 시작했다. 전 층에서 `W_hr`·`W_hz`를 0으로 고정했고, 3층은 `W_ir`·`W_iz`도 0으로 고정했다. HLS 구현은 해당 행렬곱을 생략한다. AdamW로 float 재학습한 뒤 고정소수점 C-sim 검증 세트의 평균 ACPR이 가장 낮았던 59 epoch 가중치를 선택했다. 학습은 frame 50, stride 1, batch 64, 시작 학습률 0.00025를 사용했다. 최종 RTL 시뮬레이션에서 120회 호출의 I/Q 7,680쌍은 같은 가중치를 쓴 C-sim 출력과 비트 단위로 일치했다.

## 정확도·자원·타이밍 비교

P&R은 Vivado 2024.1, `xczu7ev-ffvc1156-2-e`, `AreaOptimized_high`, 목표 15 ns에서 수행했다. 정확도는 DPA 200 MHz 테스트 세트의 고정소수점 C-sim 출력 7,680쌍을 PA 모델로 평가했다. 통과 기준은 NMSE ≤ −43.48 dB, 좌측 ACPR ≤ −50.39 dBc, 우측 ACPR ≤ −47.83 dBc다.

| 구현 | NMSE (dB) | EVM (dB) | ACPR 좌 / 우 (dBc) | II | LUT | FF | DSP | BRAM (36 Kib 타일) | WNS (ns) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| [v5-1.7](../v5-1.7/README.md) · 전 층 입력 기반 게이트 | −43.53 | −46.89 | −52.04 / −48.25 | 2 | 16,426 | 14,072 | 248 | 7.5 | +0.235 |
| [v5-3.1](../v5-3.1/README.md) · 전 층 bias-only | −32.26 | −34.19 | −37.27 / −34.83 | 2 | 13,469 | 9,071 | 187 | 7.5 | +1.569 |
| [v5-3.2](../v5-3.2/README.md) · 전 층 bias-only + 2층 가중치 우회 | −32.26 | −34.19 | −37.27 / −34.83 | 2 | 13,206 | 8,001 | 187 | 16.5 | +0.957 |
| 혼합 후보 · 2층 bias-only + 1·3층 입력 기반 | −43.71 | −47.01 | −50.98 / −49.29 | 2 | 15,337 | 12,951 | 227 | 7.5 | +0.275 |
| **v5-5 · 3층 bias-only + 1·2층 입력 기반** | **−43.89** | **−47.41** | **−50.91 / −48.91** | **2** | **15,527** | **12,660** | **228** | **7.5** | **+0.515** |

v5-1.7, v5-3.1, v5-3.2의 정확도는 각 버전의 배포 가중치 기준이다. 혼합 후보 두 개는 원본 DPD 체크포인트에서 float 재학습한 가중치를 사용했다.

두 혼합 후보 모두 정확도와 15 ns 조건을 통과했다. 3층 혼합은 2층 혼합보다 NMSE가 0.18 dB 낮고 WNS 여유가 0.240 ns 크며 FF를 291개 덜 사용했다. 2층 혼합은 LUT 190개와 DSP 1개를 덜 사용했고 좌·우 ACPR이 더 낮았다. v5-5는 v5-1.7보다 LUT 899개, FF 1,412개, DSP 20개를 줄였고 WNS 여유가 0.280 ns 늘었다.

## v5-5.1 · DSP 220개 버전

v5-5에서 PReLU 곱셈기 5개와 FEx 곱셈기 3개를 DSP에서 LUT로 옮겼다. 동일한 ZU7EV 조건에서 배치·배선한 결과 **DSP 220개, 샘플 루프 II=2, WNS +0.132 ns**로 15 ns 목표를 통과했다.

| 항목 | v5-5 | v5-5.1 | 변화 |
|---|---:|---:|---:|
| DSP | 228 | 220 | −8 |
| LUT | 15,527 | 17,349 | +1,822 (+11.7%) |
| FF | 12,660 | 12,690 | +30 (+0.2%) |
| BRAM (36 Kib 타일) | 7.5 | 7.5 | 0 |
| WNS (ns) | +0.515 | +0.132 | −0.383 |

v5-5의 가중치로 RTL을 검증했고, I/Q 7,680쌍이 기존 C-sim 출력과 비트 단위로 일치했다. [v5-5.1의 RTL·배선 보고서·검증 자료](../v5-5.1/README.md)

## PYNQ-Z2 구현 결과

PYNQ-Z2의 `xc7z020clg400-1`을 대상으로 Vivado 2024.1에서 `AreaOptimized_high`와 15 ns 제약을 적용했다. 자원과 WNS는 배치·배선 후 수치다.

| 구현 경로 | 샘플 루프 II | WNS (ns) | 비교 주기 (ns) | LUT | FF | DSP | BRAM (36 Kib 타일) |
|---|---:|---:|---:|---:|---:|---:|---:|
| ZU7EV용 RTL을 그대로 사용 | 2 | −28.129 | 43.129 | 20,729 | 13,323 | 212 | 7.5 |
| XC7Z020용 HLS 재합성 후 FIFO 최적화 적용 | 5 | −8.467 | 23.467 | 17,493 | 22,114 | 164 | 7.5 |

두 구현 모두 DSP 한도 220개 이내였다. Z2용 재합성으로 타이밍 부족분을 줄였지만 두 실험 모두 15 ns와 II=2를 동시에 충족하지 못했다. 비교 주기는 15 ns에서 WNS를 뺀 값이다. [칩·속도 등급별 HLS 및 배선 비교](../../pynq-z2-feasibility.md)

## 재현과 보고서

HLS로 생성한 RTL에 깊이 1 FIFO와 제어 공유, 입력 준비 블록의 출력 유지, GRU 1층 입력 가중치 직접 전달, PReLU 계수 폭 축소를 적용해 배선했다. 파라미터 FIFO는 386채널이며 제어는 13그룹으로 공유한다. [최종 RTL](rtl) · [배선 자원](reports/utilization.rpt) · [배선 타이밍](reports/timing_summary.rpt) · [배선 상태](reports/route_status.rpt)

- 이 폴더에서 `vitis_hls -f csynth.tcl`로 HLS 소스를 합성할 수 있다. [HLS 소스](src) · [HLS 설정](csynth.tcl) · [HLS 요약](reports/ResGRU_csynth.rpt)
- Icarus Verilog를 설치한 환경에서 `python verify.py`로 배선용 RTL과 기준 출력을 대조할 수 있다. [검증 스크립트](verify.py) · [검증 벡터](test) · [선택 가중치](weights) · [RTL 검증 결과](reports/verification.txt)
- 학습 이력에서 검증 지표와 59 epoch가 선택된 근거를 확인할 수 있다. [학습 이력](training/history.csv) · [최종 테스트 지표](training/results_float.json)
