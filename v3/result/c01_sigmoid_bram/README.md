# C01 — sigmoid 보간 표 BRAM

2026-11-05. 판단 **미정**, P&R 완료·15ns 타이밍 미달. [전체 비교](../README.md).

- 부모: [v2 최종 채택본](../../../v2/result/final/README.md). C02는 별도 분기다.
- 목적: 정확도와 II를 유지하면서 활성화 표가 차지하는 LUT를 줄일 수 있는지 확인.
- 변경: `src/activations.h`의 `sigmoid_comb`에서 동일한 256×21비트 packed 시작값·변화량 표를 로컬 static ROM으로 두고 BRAM `rom_1p`, latency=1을 요청했다. 기존 완전 분할과 함수 0클록 제약을 해제했다. tanh 표, 값과 보간 산술은 유지했다. [실제 diff](source.diff) · [조건](experiment.json).
- C-sim: 7,680개 입력에서 기존 C-sim 및 Python 참조와 Q12 불일치 0. [비교](csim_comparison.json). PA 재평가는 하지 않았다.
- csynth: 성공, 종료 코드 0. II=2, Depth=22, 추정 주기 13.840ns. LUT 203,116 / FF 128,576 / DSP 551 / BRAM_18K 15. [top 보고서](ResGRU_csynth.rpt) · [LOOP_T 보고서](Loop_LOOP_T_proc_csynth.rpt) · [sigmoid 함수 보고서](activation_csynth.rpt).
- P&R: 첫 실행은 Vivado IP 생성 단계에서 `EXCEPTION_ACCESS_VIOLATION`으로 종료됐다. [첫 시도 로그](../../../v2/package/results/final_sigmoid_bram_csynth/impl.log). 같은 합성 프로젝트를 별도 복사한 [재시도](../../../v2/package/results/final_sigmoid_bram_pnr_retry01/impl.log)는 구현·100경로 추출 종료 코드 0. WNS −0.851ns, TNS −168.906ns, setup 위반 394개, WHS +0.037ns, hold 위반 0개. 비교 주기 15.851ns, 최악 데이터 경로 지연 15.564ns. LUT 40,049 / FF 41,332 / DSP 393 / RAMB18 15개(7.5 BRAM tile) / URAM 0. [타이밍](pnr/timing_summary.rpt) · [자원](pnr/utilization.rpt) · [100경로](pnr/setup_paths100.rpt).
- RTL co-sim 및 보드 검증: 이 후보에서는 미실시. 기준본의 co-sim PASS를 이 후보에 그대로 적용하지 않는다.
- [상위 100경로 및 RTL 연결 분석](경로분석.md): 최악 경로의 끝점은 sigmoid BRAM 주소 입력이다.

기록된 `experiment.json`의 `pnr_requested=false`는 csynth 실험을 준비할 당시 상태다. 이후 사용자의 요청으로 P&R을 시작했다. 소스, 원본 로그, 전체 생성물은 [로컬 실험 폴더](../../../v2/package/results/final_sigmoid_bram_csynth/)에 있다.
