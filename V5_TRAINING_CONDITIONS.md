# v5.1 재학습 조건

이 문서의 v5.1 실제 실행 조건을 v5 후속 재학습 실험의 기본으로 사용한다. 고정 PA, float32 DPD 전체 미세조정, Adam 학습률 `0.00025`, seed `4574`, 기존 데이터 분할과 2,560샘플 프레임을 사용한다. 기본은 100 epoch이며 조기 종료는 `--early-stop`을 지정할 때만 적용한다. 검증 NMSE로 체크포인트를 선택한 뒤 테스트의 NMSE·EVM·ACPR L/R을 기록한다. 실험별로 설정을 바꾸면 변경한 항목을 결과에 기록한다.

현재 v5.1은 첨부 `v46_retraining_code.zip`의 `finetune_gru_rz.py`에서 고정 PA 학습 방식, 데이터 처리, Adam 학습률, seed 및 검증 기준을 가져왔다. 모델 구조, 업데이트 대상, 학습 중 양자화와 epoch 설정은 다르다. 아래는 ZIP에 포함된 코드의 기본값과 현재 실행 조건의 비교다. ZIP만으로 원래 실행에 사용한 명령과 옵션을 확인할 수는 없다.

| 항목 | ZIP의 `finetune_gru_rz.py` | v5.1 실제 실행 |
|---|---|---|
| 구조 | 기존 reset·update·candidate 계산을 유지하고 선택한 입력 가중치 쌍만 묶음 | 2층만 또는 세 층 모두에서 reset 계산을 없애고 update `z`를 candidate에도 사용 |
| 초기화 | 저장된 PA·DPD 체크포인트 및 `pairs.json`의 공유 계수 | 저장소의 PA·float DPD 체크포인트. 공유 층은 기존 `z`·`n` 파라미터를 복사해 시작 |
| 업데이트 대상 | 공유하도록 선택한 입력 계수만 학습 | DPD 전체 파라미터 학습. PA는 양쪽 모두 고정 |
| 학습 중 수치 형식 | 공유 계수를 Q4.10으로 양자화해 forward에 사용 | PyTorch float32. HLS에서 사용하는 고정소수점 형식은 학습 후 별도 C-sim에서 적용 |
| 최적화 | Adam, 학습률 `0.00025`, `foreach=False` | 동일 |
| epoch | 기본 최대 20, 검증 개선 없이 5 epoch 경과 시 종료 | 두 후보 각각 100 epoch, 조기 종료 비활성화. epoch 0은 업데이트 전 평가 |
| 실행 환경 | CPU 기본, DirectML 선택 가능. CPU 스레드 2개 | CPU, PyTorch `2.14.1+cpu`, 스레드 2개 |
| seed·순서 | `torch.manual_seed(4574)`, epoch마다 학습 프레임 셔플 | 동일 |

데이터는 `DPA_200MHz`를 사용한다. 학습 23,040샘플은 2,560샘플 프레임 9개이며, 한 번의 optimizer 업데이트에 한 프레임을 사용한다. 검증과 테스트는 각각 7,680샘플이다. 이득은 학습 입력·출력에서 계산하고, 학습 목표는 `gain × 입력 I/Q`다. 손실은 고정 PA를 거친 출력과 목표의 MSE를 목표 평균 제곱으로 나눈 값이다. 검증 NMSE가 가장 좋은 epoch를 선택하고 테스트에서는 NMSE·EVM·ACPR L/R을 평가한다.

ZIP의 다른 두 스크립트는 별도 실험이다. `finetune_output_fc.py`는 출력 FC의 고정소수점 연산을 모사하며 출력부만 미세조정한다. `finetune_gru_ir.py`는 1층 reset 입력 가중치의 비트폭을 줄이는 실험을 수행한다.

## 실행 명령

```powershell
python v5/train_shared_gate.py --scope layer2 --epochs 100 --no-early-stop --out build/v5_layer2_100
python v5/train_shared_gate.py --scope all --epochs 100 --no-early-stop --out build/v5_all_100
```

v4.6의 성능 기준은 NMSE −45.19 dB, EVM −48.90 dB, ACPR L/R −53.43/−50.25 dBc다. 이 수치는 최종 비교 목표이며 학습 초기화에 사용한 float DPD 체크포인트의 지표와 구분한다. [v4.6 결과](v4/README.md) · [v5.1 학습 코드](v5/train_shared_gate.py) · [고정소수점 평가 절차](v5/docs/v5.1_shared_gate.md)
