# PBL_DPD_2026_BTeam

## E20 공유 구현 기준

팀 재현 자료: [E20 안내 및 실행 순서](package/results/E20_input_precompute/README.md).

- 구현 소스는 `package/results/E20_input_precompute/src_snapshot/`에 고정되어 있습니다.
- Vitis HLS / Vivado 2024.1, XCZU7EV, 목표 클록 15 ns, 내부 샘플 II=2.
- PA NMSE -45.62 dB, ACPR L/R -53.54/-50.38 dBc. 정확도 목표 통과.
- 코어 OOC 배선 후 WNS -0.844 ns, STA 환산 주기 15.844 ns. **15 ns Setup 미달**.
- 실제 LUT 59,878 / FF 52,017 / DSP 722, BRAM·URAM 0.

E20 실행 스크립트는 작업 중인 `package/src` 대신 위 고정 소스를 사용합니다. Vivado 프로젝트·체크포인트·캐시는 재생성하며 공유 커밋에 포함하지 않습니다.
