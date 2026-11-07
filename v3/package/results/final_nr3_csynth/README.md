# C20: NR 3회

최종 v2의 NR 반복4회를3회로만 변경. inverse16,6·data15,3·weight14,4·DATAFLOW 유지. C19 sqrt 방식과 별개. 15ns / uncertainty1ns / 목표 II2 / DSP full register false. Python nr3 참조와 C-sim7680개 Q12 일치 확인 후 csynth 실행. C20/C21은 같은 부모의 병렬 대안이며 기존 결과 보존. P&R 미실시·채택 미정.

상태: status.txt, csim_comparison.json, csynth.log.

C-sim 완료:7680개 해당 Python 참조와 Q12 불일치0. csynth 진입 확인, 결과 대기 중.


## csynth ?? (2026-11-06)

C-sim 7,680? ?? Python ??? Q12 ??. LOOP_T II=2, Depth=17, HLS ?? 13.881ns/72.04MHz. LUT 221,973, FF 127,626, DSP 488, BRAM 0. ?? ?? LUT ?397, FF ?354, DSP ?1. ?? ?? 148cycle, ?? ?? 128cycle. P&R ???, ?? ??.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
