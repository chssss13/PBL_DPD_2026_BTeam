> **미사용 보관본 (2026-11-15)**: 아래 채택·최종 표기는 과거 판단이다. 이 계열은 현재 사용하지 않으며 소스와 결과만 보존한다. 현재 버전은 저장소 루트의 `v4/README.md`를 따른다. 기존 v4 번호와 새 v4 번호는 서로 다른 구현이다.

# v4.4 — recurrent 곱 포화 제거와 r/z bias 사전 합산

부모는 v4.3. 기존 A 후보의 P&R 완료 결과를 계열에 추가했다. NR4와 inverse16,5를 유지한다. recurrent r/z/n 개별 곱을 18,3으로 변환할 때 AP_SAT 대신 AP_WRAP을 사용하고, r/z bias 쌍은 Q13을 보존하는 17,4로 샘플 처리 전에 합산한다. 두 변경의 개별 기여도는 분리하지 않았다.

| PA 지표 | 골든 | v4.4 |
|---|---:|---:|
| NMSE(dB) | -45.52 | -45.40 |
| EVM(dB) | -49.42 | -49.32 |
| ACPR L(dBc) | -53.59 | -53.53 |
| ACPR R(dBc) | -50.43 | -50.29 |

7,680샘플·reset2560 C-sim이 inverse16,5 Python 출력과 Q13 전체 일치하여 해당 [PA 평가](accuracy/pa_comparison.txt)의 `z_inverse5.txt` 행을 연결했다. 모든 입력에 대한 동등성 증명은 아니다.

P&R: LUT 42,535 / FF 45,372 / DSP 504 / BRAM 0, WNS -1.433618ns, 비교 주기 16.433618ns, HLS II2. 15ns setup 미달, hold 통과 및 미배선 0. [자원](reports/utilization.rpt) · [타이밍](reports/timing_summary.rpt) · [100경로](reports/setup_paths100.rpt).

실행 원본 `v3/package/results/q13_nosat_bias_csynth`. 15ns·uncertainty1ns, Vivado 기본 구현. P&R을 완료한 후 계열에 추가했으며 팀 최종 채택을 의미하지 않는다.
