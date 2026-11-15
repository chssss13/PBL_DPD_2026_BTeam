# v4.5 — recurrent 곱 포화 제거·r/z bias 사전 합산·다항식 FEx

부모: v4.4. P&R 완료 후 다음 실험의 부모로 유지한 계열 채택본. 15ns setup은 미달이며 팀 최종 채택을 의미하지 않는다.

## 변경과 범위

부모 v4.4의 recurrent 곱 포화 제거와 bias 사전 합산을 유지하고, NR4를 정규화·지수 홀짝별 16구간 1차 다항식 FEx로 교체했다. A의 P&R 완료로 FEx 변경 전후를 따로 비교할 수 있다.

## 정확도

Python PA, 7,680샘플·reset2560. 골든과 동일 평가 조건. EVM도 함께 기록한다.

| 지표 | 골든 | 이 버전 |
|---|---:|---:|
| NMSE(dB) | -45.52 | -45.47 |
| EVM(dB) | -49.42 | -49.32 |
| ACPR L(dBc) | -53.59 | -53.51 |
| ACPR R(dBc) | -50.43 | -50.19 |

[PA 원본](accuracy/pa_comparison.txt). 여러 행이 포함된 표의 사용 행은 아래 계보 메타데이터와 상위 README를 따른다.

## P&R

LUT 40,100, FF 45,565, DSP 487, BRAM 0. 비교 주기 16.240313ns = 15−WNS, WNS -1.240313ns. HLS II=2. [자원](reports/utilization.rpt) · [타이밍](reports/timing_summary.rpt).

## 근거와 보존

실행 소스: `v3/package/results/q13_nosat_bias_poly_csynth`. 구현 결과: `q13_nosat_bias_poly_csynth`. 소스·TB를 복사 보존했으며 원본 실행 폴더는 이동하지 않았다.

새 재현 합성이나 RTL co-sim은 수행하지 않았다. C-sim/Python 일치는 해당 입력 벡터의 검증이며 모든 입력의 동등성 증명이 아니다.
