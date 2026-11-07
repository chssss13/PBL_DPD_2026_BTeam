# C02 — tanh 보간 표 BRAM

2026-11-05. 판단 **미정**, P&R 미실시. [전체 비교](../README.md).

- 부모: [v2 최종 채택본](../../../v2/result/final/README.md). C01은 별도 분기다.
- 목적: 정확도와 II를 유지하면서 활성화 표가 차지하는 LUT를 줄일 수 있는지 확인.
- 변경: `src/activations.h`의 `tanh_comb`에서 동일한 256×23비트 packed 시작값·변화량 표를 로컬 static ROM으로 두고 BRAM `rom_1p`, latency=1을 요청했다. 기존 완전 분할과 함수 0클록 제약을 해제했다. sigmoid 표, 값과 보간 산술은 유지했다. [실제 diff](source.diff) · [조건](experiment.json).
- C-sim: 7,680개 입력에서 기존 C-sim 및 Python 참조와 Q12 불일치 0. [비교](csim_comparison.json). PA 재평가는 하지 않았다.
- csynth: 성공, 종료 코드 0. II=2, Depth=18, 추정 주기 13.881ns. LUT 208,836 / FF 127,946 / DSP 491 / BRAM_18K 10. [top 보고서](ResGRU_csynth.rpt) · [LOOP_T 보고서](Loop_LOOP_T_proc_csynth.rpt) · [tanh 함수 보고서](activation_csynth.rpt).
- P&R, RTL co-sim 및 보드 검증: 미실시. 소스, 원본 로그, 전체 생성물은 로컬 실험 폴더 (로컬 보존: `../../../v2/package/results/final_tanh_bram_csynth/`)에 있다.
