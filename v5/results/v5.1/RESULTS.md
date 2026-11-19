# v5.1 입력 projection 공유 결과

**판정: HLS 선별 통과, 최종 채택 보류.** v4.6의 검증된 RTL 후처리 전체를 재현할 수 있는 입력 또는 변환 절차가 필요하다.

| 검사 | 측정 결과 |
|---|---|
| C-sim | v4.2 원본과 후보 7,680샘플 출력 파일 일치 |
| projection HLS | II=2, 깊이 2, 곱셈기 인스턴스 15개 |
| 전체 샘플 루프 HLS | `LOOP_T` II=2, 깊이 16 |
| projection HLS 추정 | 6,599 LUT / 515 FF / 15 DSP / 0 BRAM_18K, 예상 클록 주기 11.827 ns |
| 전체 HLS 추정 | 182,614 LUT / 114,571 FF / 453 DSP / 14 BRAM_18K, 예상 클록 주기 13.829 ns |
| v4.6 기준 출력·자원·전력 | 후처리 RTL co-sim, P&R 및 vectorless 전력 비교 대기 |

두 C-sim 출력 파일의 SHA-256은 `eb2a7e6746970b4f26639c2eb3bacb7c402a423fb0810578d7666707df21694c`다. 자원과 주기는 HLS 추정치다. v4.6의 배치·배선 수치를 이 값과 직접 비교해 개선율을 계산할 수 없다.

HLS 합성은 종료 코드 0으로 완료했다. `LOOP_T`의 II=2를 확인했으며, 전체 설계 요약에는 일부 루프 제약 미충족 경고가 남아 있다. 최종 채택 전에 RTL 호출 동작을 확인해야 한다.

검증 근거는 로컬 실행 폴더 `v5/prj_projection_screen/candidate/sol1/syn/report/`의 `SharedProjection_csynth.rpt`, `Loop_LOOP_T_proc_csynth.rpt`, `ResGRU_csynth.rpt`다. [변경과 실행 절차](../../docs/v5.1_projection_share.md)
