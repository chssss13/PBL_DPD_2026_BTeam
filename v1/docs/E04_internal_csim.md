# E04: FEx 16비트 중간값 후보 C-sim 검증

2026-10-16. Vitis HLS 2024.1 Windows. 두 후보 모두 전체 7680샘플,
CSim done with 0 errors. v0 package 및 golden은 변경하지 않음.

## 공통 조건과 제한

data_t 16,3 / weight_t 16,4 / accum_t 32,12, reset 간격 2560.
FEx의 제곱, 합, 진폭, 진폭제곱/세제곱 및 최종 특징은 각각 16비트 대입 시 양자화.
역수의 저장 형식만 16,3과 16,8로 비교.
sqrt와 역수는 double 수학 연산 후 해당 고정소수점 변수에 저장하며,
sigmoid/tanh도 E02의 double 계산 후 data_t 변환을 그대로 사용.
따라서 부동소수점을 제거한 회로나 모든 연산이 16비트인 회로가 아니다.
합성/RTL co-sim/II/구현 자원 및 타이밍은 이번에 실행하지 않음.

## 결과

| C 버전 | Python 비교 NMSE | PA NMSE | EVM | ACPR L/R | 판정 |
|---|---:|---:|---:|---:|---|
| E02 double FEx 후 출력 양자화 | -196.88 | -45.48 | -49.34 | -53.33/-50.37 | 통과 |
| E04 중간값 16,3 / 역수 16,3 | -196.87 | -45.06 | -49.03 | -52.99/-50.16 | 통과 |
| E04 중간값 16,3 / 역수 16,8 | -196.87 | -45.48 | -49.33 | -53.58/-50.41 | 통과 |

비교 기준 NMSE <= -60 dB. 두 파일 모두 7680x2인지 별도로 검사.
최대 파일상 차이 5e-11은 텍스트 출력 정밀도 차이 수준이며 파일 자체의 bit-exact 판정은 아님.
PA 정확도 세 기준 NMSE <= -43.48, ACPR L <= -50.39/R <= -47.83을 모두 만족.

## 재현 (v1, Vitis HLS Command Prompt)

```bat
set STEPS=csim
set NT=7680
set FEX_INTERNAL_FIXED=1
set FEX_INV_I=3
vitis_hls -f scripts/run_resgru.tcl
```

첫 출력을 별도 보관한 뒤 FEX_INV_I=8로 다시 실행.
`scripts/run_internal_csim.ps1`는 두 실행 및 소스/로그/출력 보관 절차를 포함한다.
PowerShell 스크립트 실행 정책이 제한된 환경에서는 위 cmd 명령을 사용한다.
두 실험 결과 보관 후 `python tools/verify_internal_csim.py`로 E03 참조와 비교 및 PA 평가.

기본 설정은 FEX_INTERNAL_FIXED=1 / FEX_INV_I=8.
E02 재현은 FEX_INTERNAL_FIXED=0.
원시 결과: results/E04_internal_csim/. evaluation.txt의 파일 이름은 모두 hls_out.txt이므로
순서는 golden, E02, invI3, invI8이며 첫 줄에 전체 경로를 기록함.
