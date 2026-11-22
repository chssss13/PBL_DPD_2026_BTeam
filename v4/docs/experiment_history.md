# v4 실험 이력

v3.3에서 v4.6까지 채택한 변경과 검증 기록이다. FPGA xczu7ev-ffvc1156-2-e, Vitis HLS/Vivado 2024.1, 목표 15 ns를 사용했다.

| 버전 | 부모 | 변경 문서 | 결과 |
|---|---|---|---|
| v4.0 | v3.3 | [FEx 역제곱근 정밀도 조정](v4.0_inverse_precision.md) | [측정·검증](../result/v4.0/README.md) |
| v4.1 | v4.0 | [출력 FC 누산 정밀도 확대](v4.1_output_fc.md) | [측정·검증](../result/v4.1/README.md) |
| v4.2 | v4.1 | [FEx BRAM ROM 조회](v4.2_fex_rom.md) | [측정·검증](../result/v4.2/README.md) |
| v4.3 | v4.2 | [FIFO 채널 제어 공유](v4.3_fifo_share.md) | [측정·검증](../result/v4.3/README.md) |
| v4.4 | v4.3 | [FIFO 깊이 축소](v4.4_fifo_depth.md) | [측정·검증](../result/v4.4/README.md) |
| v4.5 | v4.4 | [입력 준비 블록의 출력 레지스터 제거](v4.5_entry_registers.md) | [측정·검증](../result/v4.5/README.md) |
| v4.6 | v4.5 | [GRU 1층 가중치 직접 전달](v4.6_direct_weights.md) | [측정·검증](../result/v4.6/README.md) |

[누적 PPA 이력표](ppa_history_template.md) · [버전별 결과](../results/README.md)

## v4.7 채택 최종본

세현 v4.7에서 GRU 2층의 가중치 전달 경로를 단축했다. 배선 후 LUT 20,069개, FF 19,200개, WNS +0.051 ns를 기록했다. [검증 및 최종 RTL](../result/v4.7/README.md)
