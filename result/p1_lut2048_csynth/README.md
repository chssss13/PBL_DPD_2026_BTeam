# P1 LUT 2,048 + P2~P4: C-sim 및 HLS 합성

- 실행: 2026-10-28~29, Vitis HLS 2024.1, xczu7ev-ffvc1156-2-e, 목표 클록 15 ns.
- P1: 기존 sigmoid/tanh LUT 알고리즘, 각 2,048칸. 보간 없음, 인덱스는 0 방향 버림.
- P2: 2,560샘플마다 은닉 상태 초기화 (`RESET_ARG=1`, 블록 크기 64).
- P3: data_t / weight_t 16,3; accum_t 18,3, AP_RND / AP_SAT.
- P4: 기존 Newton-Raphson 4회, inv_sqrt만 16,8. 다른 FEx 저장값은 data_t.
- C-sim 다음 csynth 실행. P&R 및 RTL co-simulation은 실행하지 않음.

## 기능·정확도 검증

7,680샘플 C-sim 오류 0개. Python LUT2048와 비교 NMSE -196.85 dB (기준 -60 dB), PASS.
최대 절대 오차 5.000e-11: 출력 텍스트 소수점 자릿수 차이 수준이며 bit-exact라고 주장하지 않는다.
이 PASS는 Python과 C++의 기능 일치이며, 아래 PA 정확도 통과와는 다르다.

| 항목 | Python | C++ C-sim | v1 기준 | 판정 |
|---|---:|---:|---:|---|
| PA NMSE (dB) | -35.51 | -35.51 | ≤ -43.48 | 미달 |
| PA EVM (dB) | -38.06 | -38.06 | 별도 필수 기준 없음 | 참고 |
| PA ACPR L (dBc) | -46.83 | -46.83 | ≤ -50.39 | 미달 |
| PA ACPR R (dBc) | -42.97 | -42.97 | ≤ -47.83 | 미달 |

## 합성 결과

csynth_design 약 10분 37초, 정상 종료. 루프 제약 미충족 경고가 있으며 합성 실패와 구분한다.

| 항목 | 이전 P1 exact 합성 | 이번 LUT2048 + P2~P4 |
|---|---:|---:|
| LOOP_T achieved II | 72 | 7 |
| LUT (FPGA 논리 자원 수) | 360,759 | 179,090 |
| FF | 229,790 | 132,765 |
| DSP | 1,339 | 282 |
| BRAM_18K | 50 | 30 |

이전 exact 합성은 data_t/weight_t 16,2 및 기존 FEx 조건이다. 따라서 이 비교는 두 버전의 전체 결과 비교이며 P1만 변경한 통제 실험은 아니다.

- LOOP_T: iteration latency 38 cycles, trip count 64, achieved II 7. 과제 목표 II=2 미달.
- 전체 ResGRU: latency 484 cycles, 호출 interval 448 cycles (64 × 7). 호출 interval과 샘플 II를 혼동하지 않는다.
- HLS 추정 클록 주기 10.944 ns, target 15 ns, uncertainty 4.05 ns. 구현 후 타이밍 통과를 뜻하지 않는다.
- 낮은 II에서 은닉 상태의 반복 간 의존성 경고가 나옴. 자세한 내용은 logs/csynth.log.
- LUT 표의 칸 수 2,048과 위 표의 FPGA 논리 자원 LUT 수는 다른 개념이다.

## 보관 파일

- ResGRU_csynth.rpt/xml: 전체 합성 추정 자원·타이밍.
- Loop_LOOP_T_proc_csynth.rpt/xml: 루프 II·지연.
- sigmoid/tanh 함수 보고서: LUT 메모리 구현 확인.
- logs/: C-sim·합성 로그, Python 비교 및 PA 평가 결과.
- data/: C++ 출력과 Python 참조 출력.
- source/: 이번에 사용한 C++/테스트벤치/스크립트 및 Python 참조 모델 복사본.

별도 작업 폴더에서 실행했으며, 당시 소스와 보고서는 이 결과 폴더에 보관했다.
기존 package/prj_resgru 및 이전 결과는 덮어쓰지 않았다.
