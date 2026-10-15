# v0 → v1 실험 순서

아래 순서로 커밋을 구성했다. v1은 정확도와 HLS II=2 및 RTL 검증을 통과한 후보이며,
배치·배선 후 자원/타이밍까지 검증된 최종 구현은 아니다.

| 순서 | 단계 | 내용 | 결과 위치 |
|---|---|---|---|
| 0 | v0 재현 | 원본 C-sim, Python 참조, PA 정확도 | package/results |
| 1 | 작업 사본 | 원본 package를 v1으로 분리 | v1 |
| 2 | E01 | 16비트 자료형 배분 탐색 (정확 활성화/FEx) | v1/results/E01_precision |
| 3 | E02 | double 수학 기반 정확도 참조 C-sim | v1/results/E02_csim_reference |
| 4 | E03 | FEx 16비트 중간값 양자화 모사 | v1/results/E03_internal_precision |
| 5 | E04 | FEx 후보 C-sim 및 Python 대조 | v1/results/E04_internal_csim |
| 6 | E05 | double 활성화 합성, II=72 | v1/results/E05_synthesis |
| 7 | E06 | 대칭 LUT, 정확도 통과, II=5 | v1/results/E06_lut |
| 8 | E07 | 직접 조회 LUT, 정확도 통과, II=5 | v1/results/E07_direct_lut |
| 9 | E08 | 스케줄 설정 변경, II=2, 전체 RTL co-sim PASS | v1/results/E08_schedule |

각 실험 폴더의 소스 사본과 보고서는 당시 결과의 근거이며, 생성된 HLS 프로젝트는 제외했다.
표와 상세 문서는 측정 이후 정리한 기록이며 커밋 날짜를 과거로 변경하지 않았다.

현재 후보 재현은 Vitis HLS 2024.1 Command Prompt에서
`v1/scripts/run_ii2_candidate.cmd`를 사용한다. 기본 run_resgru.tcl 실행은 E08 설정과 다르다.
RTL 검증은 합성 완료 후 v1에서 `vitis_hls -f scripts/cosim_existing.tcl` 실행.
세부 수치와 한계는 E01~E05 및 E06_E08_search.md 참고.
