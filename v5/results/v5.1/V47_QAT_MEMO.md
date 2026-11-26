# v5.1 ? v4.7 기존 GRU QAT 미세조정

배포 DPD 가중치에서 시작해 기존 3층 GRU와 고정 PA를 유지했다. 학습 데이터 분할은 23,040 / 7,680 / 7,680이며 seed 4574, frame 50, batch 64, AdamW, MSE, 시작 학습률 0.00025, 최대 100 epoch를 사용했다. 학습 프레임 간격은 메모에 명시되지 않아 stride 1을 적용했다.

FP32 미세조정과 QAT를 비교한다. QAT 순전파는 v4.7의 가중치·bias, 중간 고정소수점 연산, FEx와 활성화 근사를 Python으로 모사하며 역전파에는 STE를 사용한다. HW 평가 행은 같은 Python 참조 계산과 2,560샘플 상태 초기화 간격을 사용한다. HLS C-sim과 RTL 평가는 별도다. 최종 가중치는 검증 평균 ACLR 최솟값을 기준으로 고른다.

```powershell
python v5/scripts/train_week9_qat.py original float v5/prj_week9_v47_qat/float --epochs 100 --stride 1
python v5/scripts/train_week9_qat.py original qat v5/prj_week9_v47_qat/qat --epochs 100 --stride 1
```

학습 로그, 검증 이력, 설정, 체크포인트는 `v5/prj_week9_v47_qat`에 저장한다. 기존 가중치·bias 전용 QAT의 C-sim 결과는 [기존 결과](../experiments/HARDWARE_TRAINING.md)에 있다.

| 테스트 조건 | NMSE (dB) | EVM (dB) | ACLR 좌 / 우 (dBc) | 선택 epoch | 선택 시점 학습률 | 실행 시간 |
|---|---:|---:|---:|---:|---:|---:|
| 배포 가중치 FP32 (원본 기록) | −45.52 | −49.42 | −53.59 / −50.43 | 93 | 0.001 | — |
| 배포 가중치 + HW 참조 | -45.19 | -48.90 | -53.43 / -50.25 | — | — | — |
| FP32 미세조정 + HW 참조 | -45.19 | -48.90 | -53.43 / -50.25 | 0 | 0.00025 | 397초 |
| QAT 미세조정 + HW 참조 | -45.19 | -48.90 | -53.43 / -50.25 | 0 | 0.00025 | 1354초 |

## 결과 해석

FP32 미세조정과 QAT는 모두 20 epoch에서 조기 종료됐다. 검증 평균 ACLR이 가장 낮은 체크포인트는 두 실험 모두 배포 가중치(epoch 0)였다.

동일한 Python 고정소수점 HW 참조 평가에서 v5.1의 최종 PA 성능은 v4.7과 같았다. NMSE −45.19 dB, EVM −48.90 dB, ACPR 좌·우 −53.43 / −50.25 dBc로 개선량은 모두 0.00 dB다.

## 동일 HLS C-sim 비교

v4.7과 같은 GRU 연산을 사용하는 HLS C 모델에 각 체크포인트를 내보내 같은 테스트 벡터 7,680샘플과 2,560샘플 상태 초기화 간격으로 실행했다. C-sim 출력을 동일 PA 모델로 평가했다.

| 적용 가중치 | NMSE (dB) | EVM (dB) | ACPR 좌 / 우 (dBc) |
|---|---:|---:|---:|
| 배포 가중치 | −45.19 | −48.90 | −53.43 / −50.25 |
| v5.1 최종 선택 · epoch 0 | −45.19 | −48.90 | −53.43 / −50.25 |
| 이전 가중치·bias 전용 QAT | −45.42 | −49.36 | −53.07 / −50.26 |

v5.1의 최종 선택 가중치는 모든 텐서가 배포 가중치와 같았고 C-sim 출력 파일의 SHA-256도 일치했다. 이전 QAT는 배포 가중치 대비 NMSE가 0.23 dB 낮았고, 좌측 ACPR은 0.36 dB 높았다. [이전 실험 설정과 결과](../experiments/HARDWARE_TRAINING.md)
