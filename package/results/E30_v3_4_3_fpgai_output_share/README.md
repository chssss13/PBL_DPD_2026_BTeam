# E30 / v3.4-3 — FPG-AI RNN 출력층 자원 공유 시도

FPG-AI RNN 논문의 Dense 우선 병렬도 조정 원리를 제한 적용했다. 출력 Linear(5→2)를 `Output_Project_Shared`로 분리하고 II=2 및 mul limit=5를 요청했다. 기존 MAC의 누산·반올림·포화는 유지했다.

실제 HLS 출력 모듈에는 곱셈 인스턴스 10개가 생성되어, 의도한 5개 공유는 달성하지 못했다. 원본 v3.4에는 출력층과 GRU 입력 MAC 사이에 자동 공유되는 곱셈기가 존재한다. 최종 LUT/FF는 줄었지만 전체 DSP는 5개 증가했다. 검증 7,680샘플에서 원본 Python/C 및 후보 C/RTL Q12 코드는 모두 일치했다. 새 PA 수치 평가는 수행하지 않았다.

원본 v3.4에서 독립 생성한 미채택 후보다. 원본 최종 모델을 대체하지 않는다.

| 항목 | 원본 v3.4 | 후보 |
|---|---:|---:|
| II | 2 | 2 |
| WNS(ns) | +0.145132 | +0.116 |
| LUT | 37331 | 36944 |
| FF | 38965 | 38550 |
| DSP | 362 | 367 |
| BRAM_tiles | 0 | 0 |
| URAM | 0 | 0 |

후보 RTL 최대 지연147사이클, 블록 간격134사이클. 원본 v3.4 제어 빌드와 동일하다. 코어 OOC P&R 결과이며 보드 실측·SDF 검증은 수행하지 않았다.

## 소스와 재현

- `src_snapshot/`: 실제 실험에 사용한 모델 소스의 byte 단위 복사본.
- `SOURCE_SHA256.json`: 실험 소스와 대조한 SHA-256.
- `source_changes.diff`: 원본 v3.4 대비 변경.
- `scripts/implement.tcl`: Vitis HLS/Vivado 2024.1, ZU7EV,15ns,HLS uncertainty1ns,DSP full-reg false,AreaOptimized_high 합성/P&R. 새 `build/`를 사용한다.

이 묶음은 모델 소스와 구현 스크립트다. 실행 시 공급하는 학습 가중치·입력 데이터·golden/reference 출력·native 로그·checkpoint는 포함하지 않는다. 스크립트는 C/RTL 기능 검증을 재실행하지 않으며, 기능 재현에는 원래 테스트벤치와 로컬 평가 데이터가 별도로 필요하다. 저장된 결과 수치의 전력·보드 성능으로의 확대 해석은 하지 않는다.
