# P08 — recurrent 곱 직후 포화 제거

부모: C23/v3.1. 별도 소스에서 gru_cell.h의 Recurrent_Gate_MAC(r/z)와 Recurrent_N_Row_MAC(n)의 곱 결과 변환만 AP_SAT에서 AP_WRAP으로 변경했다. signed 18/3과 AP_RND, 입력 MAC과 누산 포화는 유지했다.

2026-11-07 Vitis HLS 2024.1 C-sim PASS, 종료 코드 0. 제공 입력 7,680개(2,560개마다 상태 리셋)의 I/Q 출력이 부모 C23 출력과 Q12 기준 전부 일치했다. 불일치 0개. python_expected.txt는 부모 hls_out.txt 복사본이며 새 Python 평가가 아니다. 기존 sigmoid 32,768개 전수 검사도 통과했다.

csynth·P&R·RTL co-sim·PA 재평가 미실행. 제공 벡터의 일치이며 모든 입력에 대한 동등성 증명은 아니다. 자원 및 타이밍 효과는 미확인.

근거: source.diff, csim.log, csim_comparison.json, experiment.json. 기존 채택본은 유지한다.

2026-11-07 후속 요청: C-sim 프로젝트를 초기화하지 않고 csynth 실행. 15ns, uncertainty 1ns, 목표 II=2. csynth.log 및 csynth_status.txt에 기록. P&R 미요청.

2026-11-07 P08 csynth 정상 완료(종료 코드 0). v3.1/C23 대비 HLS LUT 212,845 → 192,560 (−20,285, −9.53%), FF 127,980 / DSP 489 / BRAM 0 동일. LOOP_T II=2, Depth=18, 추정 주기13.881ns(72.04MHz) 동일. II=1 시도 경고 이후 최종 II=2. P&R 미실행이므로 실제 자원·타이밍 효과와 채택 여부는 미확정.

2026-11-07 사용자 요청으로 P&R 실행: v3.1 채택 설정과 같은 AreaOptimized_high, 15ns. HLS export_design으로 Vivado 합성 및 배선 후 100경로 추출. 기존 csim/csynth 보존. 결과 미확정.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
