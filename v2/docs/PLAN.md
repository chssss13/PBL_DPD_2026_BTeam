# v2 실행 조건과 최종 상태

현재 v2.1·v2.2의 C 시뮬레이션, HLS 합성, RTL co-simulation, Vivado 배치배선이 완료됐다. 최종 채택본은 v2.2다.

| 조건 | 설정 |
|---|---|
| 도구 / FPGA | Vitis HLS·Vivado 2024.1 / xczu7ev-ffvc1156-2-e |
| 클록 / HLS uncertainty | 15 ns / 1 ns |
| 시간 루프 | LOOP_T II=2 |
| 호출 / 전체 검증 / reset | 64 / 7,680 / 2,560샘플 |
| 기능 검증 | 후보 Python 참조와 C, 동일 후보 C와 RTL 비교 |
| PA 조건 | NMSE≤−43.48 dB, ACPR 좌/우≤−50.39/−47.83 dBc |
| 물리 timing | setup·hold 및 배선 상태 확인 |
| 처리율 | 호출 오버헤드 제외 |

v2.1은 활성화 표의 BRAM ROM 구현을 평가했다. 실제 주기 16.850 ns로 목표를 충족하지 못했다. v2.2는 이를 유지하면서 MAC 누산을 균형 트리로 변경했고 실제 주기 14.885 ns로 통과했다. 누산 순서 변경은 후보 참조 모델과 전체 RTL 검증으로 확인했다.

상세 수치와 근거는 [v2.1](v2.1_bram_rom.md), [v2.2](v2.2_balanced_mac.md), [누적 PPA](ppa_history_template.md)에 기록한다. 재현 도구는 `scripts/run_version.py`, 순차 실행기는 `scripts/run_flow.py`다. 완료 결과의 열람만을 위해 실행하지 않는다.
