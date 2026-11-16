# E31 / v3.4-4 — FlexPWL 활성화 함수

FlexPWL 논문의 power-of-two slope와 최대 절대오차(MXE) 절편 보정을 적용했다. sigmoid/tanh 각각 입력 [-4,4),256구간,구간 내128입력코드,Q12 출력을 사용한다. 계수 항목은 26비트 signed offset + 4비트 shift이며 보간 곱셈을 shift/add로 변경했다.

논문의 2단 파이프라인 대신 0-cycle 조합 helper를 유지했다. E28의 tanh 절반 저장은 누적하지 않았다. 후보 C/RTL 7,680샘플은 서로 일치하지만 원본 출력과는 달라진다. PA 목표는 통과했으나 기존 정확도는 유지하지 못했다.

원본 v3.4에서 독립 생성한 미채택 후보다. 원본 최종 모델을 대체하지 않는다.

| 항목 | 원본 v3.4 | 후보 |
|---|---:|---:|
| II | 2 | 2 |
| WNS(ns) | +0.145132 | +0.190 |
| LUT | 37331 | 37414 |
| FF | 38965 | 38700 |
| DSP | 362 | 362 |
| BRAM_tiles | 0 | 0 |
| URAM | 0 | 0 |

후보 RTL 최대 지연147사이클, 블록 간격134사이클. 원본 v3.4 제어 빌드와 동일하다. 코어 OOC P&R 결과이며 보드 실측·SDF 검증은 수행하지 않았다.

| PA 지표 | 원본 | 후보 |
|---|---:|---:|
| NMSE_dB | -44.96005 | -43.73907 |
| EVM_dB | -48.75337 | -47.86170 |
| ACPR_L_dBc | -53.60799 | -51.42391 |
| ACPR_R_dBc | -50.30615 | -48.97870 |

## 소스와 재현

- `src_snapshot/`: 실제 실험에 사용한 모델 소스의 byte 단위 복사본.
- `SOURCE_SHA256.json`: 실험 소스와 대조한 SHA-256.
- `source_changes.diff`: 원본 v3.4 대비 변경.
- `scripts/implement.tcl`: Vitis HLS/Vivado 2024.1, ZU7EV,15ns,HLS uncertainty1ns,DSP full-reg false,AreaOptimized_high 합성/P&R. 새 `build/`를 사용한다.

이 묶음은 모델 소스와 구현 스크립트다. 실행 시 공급하는 학습 가중치·입력 데이터·golden/reference 출력·native 로그·checkpoint는 포함하지 않는다. 스크립트는 C/RTL 기능 검증을 재실행하지 않으며, 기능 재현에는 원래 테스트벤치와 로컬 평가 데이터가 별도로 필요하다. 저장된 결과 수치의 전력·보드 성능으로의 확대 해석은 하지 않는다.
