# Hidden state 식 변형 결과

호출 오버헤드는 목표 판정에서 제외한다. 추가 실험은 실행하지 않는다.

| 지표 | v2.2 기존 식 | v3.1 변형 식 |
|---|---:|---:|
| LOOP_T II | 2 | 2 |
| 15 ns 기준 처리율 (MSps) | 33.333 | 33.333 |
| PA NMSE (dB) | -43.67 | -43.67 |
| ACPR L (dBc) | -51.82 | -51.82 |
| ACPR R (dBc) | -48.38 | -48.38 |
| C/RTL 출력 단어 불일치 | 0 | 0 |
| Routed WNS (ns) | 0.115 | -0.41 |
| Routed WHS (ns) | 0.019 | 0.019 |
| 15 ns 타이밍 | PASS | FAIL |
| 구현 후 LUT | 44990.0 | 46196.0 |
| 구현 후 FF | 47877.0 | 49538.0 |
| 구현 후 DSP | 711.0 | 646.0 |
| 구현 후 BRAM_18K_equivalent | 52.0 | 56.0 |

HLS 합성 추정 자원은 metrics.json에 별도 기록한다. 구현 후 수치와 섞어 비교하지 않는다.
15 ns에서 계산한 처리율은 실제 구현이 15 ns를 통과한 경우에만 달성으로 판정한다.

Disposition: v3.1 discarded by user; retain v2.2. No further runs.
