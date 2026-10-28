# P2 + P1 수식 기반 활성화 함수: HLS 합성

- 실행 날짜: 2026-10-28, Vitis HLS 2024.1, 목표 15 ns
- 조건: P2 구간 리셋 반영, P1 수식 기반 `double` sigmoid/tanh, v0 자료형 `data_t` 16,2 / `weight_t` 16,2 / `accum_t` 18,3, FEx v0 방식
- 총 실행 시간: 약 7분 58초. HLS 합성만 실행, P&R 미실행.
- `LOOP_T` achieved II: **72** (v0는 2). 목표 II=2 미달.
- HLS 추정 자원: LUT 360,759 / FF 229,790 / DSP 1,339 / BRAM_18K 50. LUT는 추정치상 가용 230,400 대비 156%.
- 위 수치는 합성 추정치다. 최종 자원과 타이밍은 P&R 후에 확인해야 한다.
- Python의 `data_t 16,3` 실험은 이 C++ 합성 결과에 반영되지 않았다.

## 파일

- `Loop_LOOP_T_proc_csynth.rpt`: 루프 II와 지연 보고서
- `ResGRU_csynth.rpt`: 전체 회로 합성 추정 보고서
- `vitis_hls_log.txt`: 합성 로그
- `source_changes.patch`: P2 커밋 기준 이번 활성화 함수 변경 내용

수식 기반 활성화 함수는 정확도 기준을 확인하기 위한 구현이다. II=72에 이르므로 후속 LUT 등의 후보에서 정확도와 II를 함께 비교한다.
