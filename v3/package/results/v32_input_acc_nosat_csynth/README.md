# v3.2 입력 MAC 중간 누산 포화 제거

부모 v3.2. Experiment_Input_MAC의 wide_acc_t21,6만 AP_SAT→AP_WRAP. 항별18,3 포화·반올림, 최종18,3 포화 및 recurrent 연산은 유지. tanh 대칭표 후보는 포함하지 않는다.

각18,3 항은[-4,4), 다섯 항의 합[-20,20)은21,6의[-32,32)에 포함된다. 누산 소수부15비트는 동일.

15ns/uncertainty1ns/목표II2/DSP full reg false. 전체 C-sim7680 Q12 참조 일치 확인 후 csynth 자동 실행. status.txt/csynth.log/csim_comparison.json 참조. P&R 미요청, 채택 미정.

## csynth 완료 및 P&R 요청

C-sim7680 Q12 불일치0. HLS II2/Depth18,13.840ns,LUT187610/FF127877/DSP489/BRAM0. v3.2 대비 LUT−4950/FF−103. 사용자 요청으로 15ns/AreaOptimized_high P&R 실행. 타이밍 개선만으로도 채택 검토 가능하다는 사용자 판단을 기록한다. 최종 결과는 미확정이며 timing100 보고서로 확인한다.

## 최종 결과와 사용자 판단 — 2026-11-07

**보류. 현재 채택본은 v3.2 유지.** 이후 다른 변경과 조합하거나 비교할 수 있는 후보로 소스·결과를 보존한다.

동일15ns/AreaOptimized_high P&R: LUT38240 / FF40732 / DSP362 / BRAM0, WNS+0.147886ns, 비교 주기14.852114ns. v3.2 대비 LUT+193, FF−228, DSP 동일, WNS 여유−0.007601ns. 명확한 자원·타이밍 동시 개선은 아니므로 지금은 채택하지 않는다. [판단 기록](decision.json).
