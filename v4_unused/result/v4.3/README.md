> **미사용 보관본 (2026-11-15)**: 아래 채택·최종 표기는 과거 판단이다. 이 계열은 현재 사용하지 않으며 소스와 결과만 보존한다. 현재 버전은 저장소 루트의 `v4/README.md`를 따른다. 기존 v4 번호와 새 v4 번호는 서로 다른 구현이다.

# v4.3 — inverse_t16,6 →16,5

부모: v4.2. P&R 완료 후 다음 실험의 부모로 유지한 계열 채택본. 15ns setup은 미달이며 팀 최종 채택을 의미하지 않는다.

## 변경과 범위

inverse의 소수부가 10비트에서 11비트로 증가한다. 가중치 예외 처리와 z 축소는 포함하지 않는다. PA 표의 z_inverse5 행을 사용하며 가중치·z 값 보존을 근거로 수치 대응한다.

## 정확도

Python PA, 7,680샘플·reset2560. 골든과 동일 평가 조건. EVM도 함께 기록한다.

| 지표 | 골든 | 이 버전 |
|---|---:|---:|
| NMSE(dB) | -45.52 | -45.40 |
| EVM(dB) | -49.42 | -49.32 |
| ACPR L(dBc) | -53.59 | -53.53 |
| ACPR R(dBc) | -50.43 | -50.29 |

[PA 원본](accuracy/pa_comparison.txt). 여러 행이 포함된 표의 사용 행은 아래 계보 메타데이터와 상위 README를 따른다.

## P&R

LUT 44,496, FF 47,802, DSP 554, BRAM 0. 비교 주기 16.775883ns = 15−WNS, WNS -1.775883ns. HLS II=2. [자원](reports/utilization.rpt) · [타이밍](reports/timing_summary.rpt).

## 근거와 보존

실행 소스: `v3/package/results/q13_inverse5_only_csynth`. 구현 결과: `q13_inverse5_only_pnr_retry01`. 소스·TB를 복사 보존했으며 원본 실행 폴더는 이동하지 않았다.

새 재현 합성이나 RTL co-sim은 수행하지 않았다. C-sim/Python 일치는 해당 입력 벡터의 검증이며 모든 입력의 동등성 증명이 아니다. v4.2는 당시 별도 C-sim 없이 Python 수치 비교 및 합성·P&R을 진행했다.
