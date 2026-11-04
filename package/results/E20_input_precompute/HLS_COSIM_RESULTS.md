# E20 C 합성 및 RTL co-sim 결과

> 이 문서는 합성·co-sim 단계의 기록입니다. 후속 implementation도 완료했으며 실제 WNS -0.844 ns, LUT 59,878 / FF 52,017 / DSP 722입니다. [배선 후 비교표](IMPLEMENTATION_RESULTS.md)를 확인하세요.

기준은 E18 HLS 결과입니다. 동일 FPGA xczu7ev-ffvc1156-2-e, 목표 15 ns, uncertainty 4.05 ns입니다.
아래 자원·클록 주기는 HLS 추정치이며 실제 배선 결과가 아닙니다.

| 항목 | E18 HLS | E20 HLS |
|---|---:|---:|
| 내부 LOOP_T II | 2 | 2 |
| 파이프라인 depth | 27 | 27 |
| 추정 클록 주기(ns) | 11.504 | 11.689 |
| top latency(cycles) | 158.0 | 158.0 |
| top interval(cycles) | 128.0 | 128.0 |
| 추정 LUT | 199590 | 198240 |
| 추정 FF | 148820 | 148120 |
| 추정 DSP | 725 | 725 |
| 추정 BRAM_18K | 0 | 0 |
| 추정 URAM | 0 | 0 |

추정 주기 변화(E20−E18): +0.185 ns.
II=2 충족: True. 유효 HLS 예산 10.950 ns 충족: False.

추정 LUT는 1,350개, FF는 700개 감소하고 DSP는 같습니다. HLS 최악 경로에는 여전히 재귀 MAC과 gate 입력 합산이 포함됩니다. E18은 r 쪽, E20은 z_pre 쪽이 최악이며 합산의 보고 지연은 각각 0.698/0.884 ns입니다. [경로 근거](critical_path_comparison.json).

RTL co-sim 2,624샘플(리셋 2,560 경계 포함) PASS 및 C-sim/E18 Q14 코드 일치입니다.
C-sim 7,680샘플 PA NMSE -45.62 dB, ACPR L/R -53.54/-50.38 dBc로 정확도 PASS입니다.

Implementation과 IP export는 실행하지 않았습니다. 실제 자원·배선 타이밍 개선은 미확인입니다.
작업 src와 고정 reference는 E18을 유지합니다.

[루프 보고서](hls_reports/Loop_LOOP_T_proc_csynth.rpt), [상위 보고서](hls_reports/ResGRU_csynth.rpt), [co-sim 보고서](ResGRU_cosim.rpt).
