# v0 → v1 실험 순서

실험 버전 표기는 E01~E09에서 v1.1~v1.9로 변경했다.
문서·결과 폴더·현재 실행 스크립트의 경로도 같은 규칙으로 변경했다.
각 버전 폴더는 당시 결과와 소스 사본이며 독립적인 전체 프로젝트 복사본은 아니다.
과거 도구 로그·보고서·소스 사본 내부의 E01~E09 및 옛 절대경로는 원본 증거로 유지한다.
예를 들어 로그의 E08은 현재 v1.8을 뜻한다. prj_e08 프로젝트 이름도 유지한다.

아래 순서로 커밋을 구성했다. v1은 정확도와 HLS II=2 및 RTL 검증을 통과한 후보이며,
배치·배선 후 자원/타이밍까지 검증된 최종 구현은 아니다.

| 순서 | 단계 | 내용 | 결과 위치 |
|---|---|---|---|
| 0 | v0 재현 | 원본 C-sim, Python 참조, PA 정확도 | v0/results |
| 1 | 작업 사본 | 원본 package를 v1으로 분리 | v1 |
| 2 | v1.1 | 16비트 자료형 배분 탐색 (정확 활성화/FEx) | v1/results/v1.1_precision |
| 3 | v1.2 | double 수학 기반 정확도 참조 C-sim | v1/results/v1.2_csim_reference |
| 4 | v1.3 | FEx 16비트 중간값 양자화 모사 | v1/results/v1.3_internal_precision |
| 5 | v1.4 | FEx 후보 C-sim 및 Python 대조 | v1/results/v1.4_internal_csim |
| 6 | v1.5 | double 활성화 합성, II=72 | v1/results/v1.5_synthesis |
| 7 | v1.6 | 대칭 LUT, 정확도 통과, II=5 | v1/results/v1.6_lut |
| 8 | v1.7 | 직접 조회 LUT, 정확도 통과, II=5 | v1/results/v1.7_direct_lut |
| 9 | v1.8 | 스케줄 설정 변경, II=2, 전체 RTL co-sim PASS | v1/results/v1.8_schedule |

각 실험 폴더의 소스 사본과 보고서는 당시 결과의 근거이며, 생성된 HLS 프로젝트는 제외했다.
표와 상세 문서는 측정 이후 정리한 기록이며 커밋 날짜를 과거로 변경하지 않았다.

현재 후보 재현은 Vitis HLS 2024.1 Command Prompt에서
`v1/scripts/run_ii2_candidate.cmd`를 사용한다. 기본 run_resgru.tcl 실행은 v1.8 설정과 다르다.
RTL 검증은 합성 완료 후 v1에서 `vitis_hls -f scripts/cosim_existing.tcl` 실행.
세부 수치와 한계는 v1.1~v1.5 및 v1.6_v1.8_search.md 참고.
