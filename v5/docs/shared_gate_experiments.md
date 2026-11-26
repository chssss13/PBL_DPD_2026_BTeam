# v5.1 GRU 게이트 공유 실험

[v4.7 RTL resource comparison](../results/experiments/V47_RESOURCES.md)

2층만 공유하는 `layer2`와 세 층 모두 공유하는 `all`을 비교했다. 두 후보는 내부 비교용으로 보존한다. v4.6은 성능 비교 기준이다. [v4.6 결과](../../v4/result/v4.6/README.md)

## 모델과 학습 조건

공유 대상으로 지정한 층에서는 reset 입력·recurrent 행렬곱과 bias를 제거한다. update 값 `z`를 후보 상태 계산 `n = tanh(x_n + z * h_n)`과 상태 갱신 `h = n + z * (h_prev - n)`에 사용한다. hidden size 5, 3층 residual, FEx와 입출력 구조를 유지한다. 제거되는 모델 연산량은 2층 공유 50회, 전 층 공유 150회/샘플이다.

- 기존 float DPD 체크포인트로 초기화한다. 공유 층은 기존 update·candidate 계수를 복사한다. PA는 고정하고 DPD 전체를 float32로 미세조정한다.
- CPU PyTorch 2.14.1, 스레드 2개, seed 4574, Adam 학습률 0.00025, 프레임 단위 셔플을 사용한다. 각 후보는 조기 종료 없이 100 epoch를 수행했다. 검증 NMSE로 선택한 체크포인트는 두 후보 모두 100 epoch였다.
- DPA_200MHz 학습 23,040개, 검증·테스트 각각 7,680개를 사용한다. 프레임 길이는 2,560샘플이며 매 프레임에서 상태를 초기화한다. 목표는 학습 세트에서 계산한 gain과 입력 I/Q의 곱이다. 고정 PA의 출력과 목표 사이의 정규화 MSE를 최소화한다.
- 제공된 ZIP의 `finetune_gru_rz.py`에서 고정 PA, 데이터 처리, 학습률, seed와 검증 기준을 참고했다. ZIP의 해당 코드는 기존 구조에서 일부 Q4.10 입력 가중치만 공유하도록 학습하며, 기본 최대 20 epoch·patience 5를 사용한다. 실제 원본 실행 옵션은 ZIP에서 확인되지 않았다. 이후 v5 학습은 이번 v5.1 조건을 기본으로 한다.

## 하드웨어 변경과 검증

v4.2 HLS 소스로 두 게이트 공유 후보를 만들었다. 2층 후보에서는 분기 상수화를 위해 층 루프도 unroll했다. HLS가 생성한 RTL에 FIFO 제어 공유, 깊이 1, 생산 블록 출력 레지스터 제거를 적용한 뒤 1층 가중치를 FIFO에서 곱셈기 쪽으로 직접 연결했다. 2층 공유는 75개, 전 층 공유는 50개다. 변환 기록과 실제 검증한 Verilog는 후보별 산출물에 있다.

원래 HLS 프로젝트에서 100 epoch 가중치로 XSim co-sim을 실행했다. 2층 후보는 Windows 파일 열기 한도를 2,048로 설정하고 후보 디렉터리 기준의 C++ 경로를 사용해 테스트 벤치 오류를 해결했다. 두 후보 모두 7,680샘플의 C-sim 대비 Q12 불일치가 0개다. 호출 지연/간격은 2층 146/134클록, 전 층 144/134클록이다.

## 정확도 및 PPA 결과

| 후보 | float NMSE (dB) | 고정소수점 NMSE (dB) | EVM (dB) | ACPR L/R (dBc) |
|---|---:|---:|---:|---|
| v4.6 기준 | — | −45.19 | −48.90 | −53.43 / −50.25 |
| 2층 공유 | −41.13 | −40.90 | −42.88 | −46.90 / −47.66 |
| 전 층 공유 | −31.23 | −31.14 | −33.18 | −39.12 / −40.58 |

표의 EVM·ACPR은 고정소수점 결과다. 이번 학습 설정에서 NMSE는 v4.6보다 각각 4.29 dB와 14.05 dB 악화했다. 최종 구조 채택 여부는 미확정이다.

| 후보 | Vivado 합성 직후 WNS | 배선 후 WNS | 배선 후 WHS | LUT | FF | DSP | BRAM 타일 |
|---|---:|---:|---:|---:|---:|---:|---:|
| v4.6 보관 기준 | — | +0.138 ns | — | 21,660 | 19,171 | 347 | 7.5 |
| 2층 공유 | −1.036 ns | +0.021 ns | +0.019 ns | 20,016 | 18,473 | 353 | 7.5 |
| 전 층 공유 | −1.403 ns | +0.165 ns | +0.039 ns | 16,371 | 14,045 | 270 | 7.5 |

v5.1은 Vivado 2024.1 OOC 구현, xczu7ev-ffvc1156-2-e, 15 ns 기준이다. 두 후보 모두 HLS 샘플 루프 II=2, 배선 후 setup·hold 위반과 배선 오류 0개다. 합성 직후 타이밍은 두 후보 모두 미달했다. v4.6은 이전 구현의 보관 보고서 수치이므로 동일 OOC 흐름으로 재측정한 비교에는 해당하지 않는다. 전력과 보드 실측은 미실시다.

## 실행 및 산출물

- [실행 스크립트](../scripts/)에 학습, 가중치 내보내기, HLS 후보 생성, RTL 변환, Vivado 합성과 배치·배선 스크립트가 있다. 스크립트의 로컬 작업 경로는 `build/v5_<scope>_100/` 및 `v5/prj_shared_<scope>/`다.
- 학습은 저장소 루트에서 `python v5/scripts/train_shared_gate.py --scope layer2 --out build/v5_layer2_100`으로 실행한다. 전 층 공유는 `--scope all --out build/v5_all_100`을 사용한다. 기본값은 100 epoch이며 조기 종료는 `--early-stop`을 지정할 때 적용한다.
- 후보 생성은 `python v5/scripts/prepare_shared_hls.py layer2` 후 `SHARED_SCOPE=layer2`를 설정하고 `vitis_hls -f v5/scripts/shared_hls.tcl`을 실행한다. 학습 가중치의 고정소수점 평가는 `v5/scripts/evaluate_shared_hls.ps1 -Scope layer2`를 사용한다. 전 층 후보는 `all`을 지정한다.
- [2층 산출물](../results/experiments/layer2/)과 [전 층 산출물](../results/experiments/all/)에 각각 HLS 소스, 최종 RTL·ROM, 내보낸 가중치, 학습 체크포인트, C-sim·RTL 출력, 변환 감사 기록, HLS·Vivado 리포트와 SHA-256 목록을 보관한다. Vivado 작업 DB와 DCP는 로컬 작업 경로에 보관한다.
