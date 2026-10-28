# LUT 4096 반올림 + weight 16,4 + FEx inv 16,6: C-sim과 합성

**한 줄 요약:** 4,096칸 반올림 LUT 후보는 PA 정확도를 통과했으나 HLS II=7이었다.

- 날짜: 2026-10-29, Vitis HLS 2024.1, xczu7ev-ffvc1156-2-e, 목표 15 ns.
- P1: sigmoid/tanh 4096칸, 근접 인덱스 반올림 (동점은 큰 인덱스).
- P2: 64개 블록, 2560개 샘플 구간마다 reset (`RESET_ARG=1`).
- P3: data_t 16,3 / weight_t 16,4 / accum_t 18,3 (AP_RND, AP_SAT).
- P4: Newton-Raphson 4회, inv_sqrt 16,6; FEx 기타 중간값 data_t.
- C-sim: 7680샘플, 오류 0. Python 비교 NMSE -196.85 dB, 최대 오차 5e-11, PASS. 출력 파일 소수점 자리 차이가 있으며 bit-exact 주장 아님.
- C-sim PA 결과: NMSE -43.57 dB, EVM -47.70 dB, ACPR L/R -51.26 / -48.02 dBc. NMSE/ACPR 세 기준 통과, NMSE 여유 0.09 dB.
- 합성: csynth_design 약 11분 2초, 정상 종료. `LOOP_T` achieved II=7, 목표 II=2 미달, depth=38.

| HLS 자원 추정 | 이전 LUT2048 버림 후보 | 이번 LUT4096 반올림 후보 |
|---|---:|---:|
| LUT | 179,090 | 179,429 |
| FF | 132,765 | 132,816 |
| DSP | 282 | 279 |
| BRAM_18K | 30 | 60 |

이전 후보는 weight_t 16,3, inv_sqrt 16,8, LUT2048 버림이므로 차이 전체를 LUT 칸 수만의 효과라고 할 수 없다.
이번 HLS estimated clock 10.933 ns (target 15 ns, uncertainty 4.05 ns)는 추정치이며 P&R timing 통과가 아니다. RTL co-sim과 P&R은 미실행.

- ResGRU_csynth.rpt/xml: 전체 자원·클록 추정.
- Loop_LOOP_T_proc_csynth.rpt/xml: 루프 II와 지연.
- logs/: 합성 및 C-sim 로그.
- data/: C-sim과 Python 출력.
- source/: C-sim과 합성 당시 파일과 일치하는지 확인한 C++ 소스, 테스트벤치, 실행 스크립트 복사본.
