# E20: 독립 연산 사전 계산 C-sim 결과

> 아래는 선행 C-sim 기록입니다. 후속 [C 합성·co-sim](HLS_COSIM_RESULTS.md)과 [implementation](IMPLEMENTATION_RESULTS.md)도 완료했습니다. 내부 II=2, RTL co-sim PASS, 실제 WNS -0.844 ns로 E18보다 0.313 ns 개선됐지만 15 ns는 미달입니다. 고정 reference는 E18입니다.

기준은 E18입니다. 7,680샘플, 리셋 간격 2,560, PA 평가 2,560샘플씩 3구간 조건을 유지했습니다.

| 후보 | PA NMSE(dB) | EVM(dB) | ACPR L(dBc) | ACPR R(dBc) | 정확도 목표 |
|---|---:|---:|---:|---:|---|
| E18 | -45.62 | -49.45 | -53.54 | -50.38 | PASS |
| E20 | -45.62 | -49.45 | -53.54 | -50.38 | PASS |

전체 7,680샘플의 I/Q Q14 출력 코드가 E18과 일치합니다. 최대 코드 오차 0 LSB입니다.

1. 입력 MAC과 r/z의 입력·재귀 bias를 own h_prev와 독립적인 준비 함수로 분리했습니다.
2. hidden n MAC+bias는 h_prev에는 의존하지만 r에는 의존하지 않으므로 별도 준비합니다.
3. z와 z*h_prev를 r→n 분기보다 먼저 표현했습니다. 최종 h_next 식은 유지합니다.

C-sim은 수치 동작 검증입니다. 실제 선행 실행/병렬화, II, 자원, 타이밍 개선은 아직 확인하지 않았습니다.
C 합성·RTL co-sim·implementation은 실행하지 않았습니다. E18 수치를 E20의 성능으로 재사용할 수 없습니다.
작업 src는 E18을 유지하고 후보는 src_snapshot에 보존했습니다.
