# 실험 결과

v0부터 최근 실험까지 시간순으로 정리했다. 각 폴더의 README 첫 부분에서 조건과 결과를 확인할 수 있다.

| 순서 | 실험 | 한 줄 요약 |
|---|---|---|
| 00 | [v0](00_v0/README.md) | 기준 동작을 확인했고 정확도와 15ns 타이밍은 미달했다. |
| 01 | [구간 리셋](01_reset/README.md) | 2,560샘플 구간 리셋을 적용하고 C-sim을 확인했다. |
| 02 | [수식 기반 활성화](02_exact/README.md) | 정확도 확인용 수식의 HLS II가 72였다. |
| 03 | [LUT 2,048](03_lut2048/README.md) | LUT 도입 후 HLS II=7이었고 PA 정확도는 미달했다. |
| 04 | [LUT 4,096](04_lut4096/README.md) | 반올림 LUT로 정확도는 통과했지만 HLS II=7이었다. |
| 05 | [스케줄 설정](05_schedule/README.md) | 합성 설정을 바꿔 HLS II를 3으로 줄였다. |
| 06 | [상태 갱신 수식](06_state/README.md) | 출력을 유지하면서 수식을 바꿨고 HLS II는 3이었다. |
| 07 | [LUT 조회 구조](07_lut_lookup/README.md) | HLS II=2, RTL 정확도 통과. Vivado 배선 후 17.506ns로 15ns는 미달했다. |

07번의 [RTL co-sim](07_lut_lookup/01_cosim/README.md)과 [Vivado 구현](07_lut_lookup/02_implementation/README.md)은 순서대로 별도 보관했다. II와 HLS 자원은 추정치이며, 최종 물리 타이밍과 구분한다.
