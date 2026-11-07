# C21: NR 2회

최종 v2의 NR 반복4회를2회로만 변경. inverse16,6·data15,3·weight14,4·DATAFLOW 유지. C19 sqrt 방식과 별개. 15ns / uncertainty1ns / 목표 II2 / DSP full register false. Python nr2 참조와 C-sim7680개 Q12 일치 확인 후 csynth 실행. C20/C21은 같은 부모의 병렬 대안이며 기존 결과 보존. P&R 미실시·채택 미정.

상태: status.txt, csim_comparison.json, csynth.log.

C-sim 완료:7680개 해당 Python 참조와 Q12 불일치0. csynth 진입 확인, 결과 대기 중.


## csynth ?? (2026-11-06)

C-sim 7,680? ?? Python ??? Q12 ??. LOOP_T II=2, Depth=16, HLS ?? 13.881ns/72.04MHz. LUT 220,916, FF 126,838, DSP 482, BRAM 0. ?? ?? LUT ?1454, FF ?1142, DSP ?7. ?? ?? 147cycle, ?? ?? 128cycle. P&R ???, ?? ??.

## P&R 시작 (2026-11-06)
사용자 요청으로 기존 csynth RTL을 사용해 15ns 표준 HLS export implementation 실행. 이전 C-sim·csynth 결과는 보존하며 완료 후 timing100에 setup100경로·타이밍 요약·자원 보고서를 자동 추출. 로그 impl.log, 상태 impl_status.txt. 타이밍·자원 결과는 대기 중.


## P&R ?? (2026-11-06)

15ns IP ?? ?? WNS ?0.473888ns / WHS +0.036848ns / ??? 0, ???? 15.474ns? setup ??. ?? ??? ?? ?? 15.455ns(?? 7.971 / ?? 7.484). ?? ? LUT 40,897 / FF 41,513 / DSP 355 / BRAM 0. ?? v2 ?? LUT ?490, FF +425, DSP ?7. HLS ?? ? ???? 13.838ns. ??? 100?? ?? ??. ?? ?? ??.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
