# 16비트 입력/가중치, 정확도, II=2 탐색

2026-10-16. v0 원본 및 golden 수정 없음. 재학습 없음.

| 후보 | PA NMSE | ACPR L/R | LOOP_T II |
|---|---:|---:|---:|
| E05 double 활성화 | -45.48 | -53.58/-50.41 (E04 C) | 72 |
| E06 대칭 half-domain LUT | -43.65 | -51.86/-48.23 | 5 |
| E07 직접 조회 LUT | -43.67 | -51.82/-48.38 | 5 |
| E08 E07 계산 + 스케줄 설정 | -43.67 | -51.82/-48.38 (동일 C 계산) | **2** |

E06/E07 모두 전체 7680샘플 C-sim 완료 및 Python 비교 PASS (약 -196.93 dB).
E08은 계산을 바꾸지 않고 합성 설정만 변경. 합성 종료 코드 0, Verilog/VHDL 생성.
역수와 sqrt는 여전히 double 수학 연산을 사용하며 결과 저장은 16비트.
sigmoid/tanh는 런타임 부동소수점 없이 정수 LUT 조회로 구현.
입력/data_t 16,3, 가중치 16,4, 주요 누산기 32,12. 출력층 누산 data_t.

## E08 설정

- ACT_LUT=2: 4096-entry signed direct lookup, spacing 1/512, bin midpoint.
- LUT 저장값은 data_t의 raw integer. 입력 비트 [15:4]를 인덱스로 사용.
- FEX_INTERNAL_FIXED=1, FEX_INV_I=8.
- 2560샘플마다 reset, 64샘플 호출 사이에는 상태 유지.
- DSP_FULL_REG=false, CLOCK_UNCERTAINTY_NS=1.0, target clock 15 ns.
- TARGET_II=2 요청. 실제 보고서 LOOP_T achieved II=2, depth=37.
- 진짜 재귀 의존성을 false로 선언하지 않음, 시퀀스 interleaving 없음.

## E08 HLS 보고서

| 항목 | 값 |
|---|---:|
| 64샘플 top latency | 168 cycles / 2.520 us |
| top interval | 128 cycles |
| 추정 clock | 13.998 ns (uncertainty 1.0 ns) |
| LUT | 243879 (105%) |
| FF | 143893 |
| DSP | 711 |
| BRAM_18K | 0 |

LUT/타이밍은 HLS 추정값이며 배치배선 결과가 아니다.
기본 4.05 ns보다 clock uncertainty를 줄였으므로 물리 구현에서 timing closure가 필요.
따라서 정확도(C)와 II(HLS) 조건의 후보를 찾았지만 보드 구현 성공으로 해석하면 안 됨.
로그의 'All loop constraints were NOT satisfied'는 남아 있음; 최상위 LOOP_T achieved=2를
보고서에서 직접 확인했으며 모든 하위 pragma 조건 충족을 의미하지는 않음.

## 재현

Vitis HLS 2024.1 Command Prompt에서 v1/scripts/run_ii2_candidate.cmd 실행.
Python 참조: python tools/evaluate_lut_candidate.py --experiment results/E07_direct_lut --act lut_direct
검증: python tools/validate_candidate.py results/E07_direct_lut
합성 보고서 사본: results/E08_schedule/report.

## RTL co-sim

scripts/cosim_existing.tcl로 기존 합성 프로젝트를 초기화 없이 사용.
첫 시도는 C TB의 TV file 생성 단계에서 Error on TV file로 실패 (RTL 미실행).
포트별 TV 파일이 Windows 기본 stdio 한도를 넘을 가능성에 대응해 TB main에서
_setmaxstdio(2048)를 호출하도록 수정하고 재시도함. 결과는 cosim_retry.log 확인.

재시도 성공: 전체 7680샘플/120블록, C/RTL co-simulation PASS, 종료 코드 0.
Verilog co-sim top latency 166 cycles, top call interval 134 cycles.
이 top 호출 간격은 64샘플 단위의 제어 핸드셰이크를 포함하며 LOOP_T의 샘플 II=2와 구분한다.
RTL 출력 vs Python 참조 NMSE -196.93 dB, PASS.
RTL PA 평가 NMSE -43.67, EVM -47.64, ACPR L/R -51.82/-48.38.
세 정확도 기준 모두 통과. NMSE 여유는 약 0.19 dB로 작음.
평가 로그: results/E08_schedule/rtl_evaluation.txt, rtl_compare.txt.
co-sim 보고서 사본: results/E08_schedule/report/ResGRU_cosim.rpt.

현재 기본 ACT_LUT는 1이므로 성공 후보는 반드시 run_ii2_candidate.cmd의 ACT_LUT=2 및
스케줄 설정으로 재현한다. 단순 기본 명령은 같은 후보를 재현하지 않는다.
