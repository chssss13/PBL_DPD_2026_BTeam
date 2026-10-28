# 4096칸 조합 조회 및 상태 갱신 수식 합성 실험

**한 줄 요약:** 조합 LUT 조회로 HLS II=2와 RTL 정확도를 달성했으나 배선 후 15ns 타이밍은 미달했다.

2026-10-29. 4096칸 활성화 표의 기존 값과 인덱스 반올림을 유지하고, 표를 전체 분할하여 조회 지연 0을 요청했다. GRU 상태 갱신은 `n + z * (h_prev - n)`을 사용했다. `data_t=16,3`, `weight_t=16,4`, `accum_t=18,3`, FEx 역제곱근 `16,6`, 2560샘플 초기화. 합성은 15ns, uncertainty 1ns, DSP full reg false, LOOP_T II=2 요청.

- sigmoid/tanh에 가능한 65,536개 입력 각각에서 이전 LUT 출력과 새 LUT 출력이 모두 일치했다.
- C-sim 7,680샘플, 오류 0. 결과 파일은 직전 상태 갱신 수식 버전의 C-sim 출력과 SHA-256이 일치한다. PA 재평가는 수행하지 않았다.
- csynth 정상 종료: LOOP_T achieved II=2, depth=19. sigmoid/tanh 조회 지연 보고서 각각 0클록.
- 추정 주기 13.961ns, LUT 263,695/230,400 (114%), FF 142,769, DSP 585, BRAM_18K 0. HLS 추정치이며 실제 구현 결과가 아니다.
- `All loop constraints were NOT satisfied` 경고가 남았다. 당시 RTL co-sim과 P&R은 수행하지 않았다. 이후 RTL co-sim은 PASS했으며 결과는 [co-sim 기록](01_cosim/README.md)에 있다. 이후 [P&R 결과](02_implementation/README.md)에서 LUT 60,349개로 수용됐으나 배선 후 주기 17.506ns로 목표 15ns에 미달했다.

비교: 직전 상태 갱신 수식 + BRAM 조회는 II=3, 13.961ns, LUT 197,736, FF 147,433, DSP 692, BRAM_18K 160.

로그는 `logs/`, 합성 소스와 Tcl 스크립트는 `source/`, 모델 출력은 `hls_out.txt`에 보관한다. `source/generate.cpp`는 이전 구현의 활성화 표 값을 출력한 생성기, `source/check_lut.cpp`는 두 조회 방식의 전 입력 비교 코드다.
