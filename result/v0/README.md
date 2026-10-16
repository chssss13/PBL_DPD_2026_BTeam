# v0 실행 결과

- 브랜치: sehyeon
- 수집 날짜: 2026-10-16
- 결과 수집 시 소스 커밋: 1d1d643b8873545937cfdcbc7cf988e007b03ec6
- 환경: Windows / Vitis HLS·Vivado 2024.1 / xczu7ev-ffvc1156-2-e / 목표 15 ns

| 항목 | 결과 |
|---|---:|
| 참조 대비 NMSE | -82.66 dB, PASS |
| PA NMSE | -26.67 dB |
| PA EVM | -28.10 dB |
| PA ACPR L / R | -39.48 / -36.09 dB |
| LUT / FF / DSP | 46646 / 49546 / 648 |
| BRAM | 0 |
| 구현 후 클록 주기 | 17.129 ns |
| 타이밍 | 미충족 (목표 15 ns) |

## 파일

- logs/compare.txt: Python 참조와 HLS 출력 비교
- logs/accuracy.txt: PA 통과 정확도 (torch_out은 float 기준, hls_out은 v0)
- ResGRU_export.rpt: 구현 자원·타이밍
- ResGRU_csynth.rpt, Loop_LOOP_T_proc_csynth.rpt: 합성·루프 보고서
- logs/impl_log.txt: 전체 합성·구현 로그
- data/hls_out.txt: HLS C-sim 출력
- data/ref_v0.txt, data/ref_exact.txt: Python 참조 출력

v0는 정확도와 타이밍 목표에 미달하는 출발점이다.
