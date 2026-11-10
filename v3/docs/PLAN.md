# v3 검증 조건과 채택 상태

기준 원본은 [BASELINE](../BASELINE.md), 최종 채택본은 [v3.3](../results/v3.3/RESULTS.md)이다. 기준 소스·입력·가중치와 원본 보고서를 보존하고 후보는 experiments에서 분리한다.

| 필수 조건 | 기준 |
|---|---|
| 스케줄 | LOOP_T II=2 |
| 물리 timing | 15 ns setup/hold 통과, 배선 오류·미배선 0 |
| PA 정확도 | NMSE≤−43.48 dB, ACPR 좌/우≤−50.39/−47.83 dBc |
| 기능 | 후보 독립 참조/C 및 동일 후보 C/RTL 전체 검증 |
| 입력 | 7,680샘플·64샘플 호출·2,560샘플 reset |
| 처리율 | 호출 오버헤드 제외 |

v3.1은 기존 원본에서 inverse 정밀도 재배분으로 ACPR을 개선했다. v3.2는 보정 seed·NR 감소로 DSP를 줄였고 v3.3은 sigmoid multipartite로 LUT를 줄였다. [논문 근거](PAPER_CANDIDATES.md)와 [결과 목록](../results/README.md)을 따른다.

후속 자원 후보는 부모 대비 자원 1% 이상 감소, 다른 자원 증가 1% 이하·BRAM 신규 사용 없음이라는 현재 선별 기준과 필수 조건을 함께 확인한다. 미달 후보는 소스·결과·상세 문서를 실제 삭제한다. 삭제 전 최종 수치는 공통 실행 로그에 기록한다.

입력 인터페이스와 기준 데이터는 유지한다. 후속 논문은 IEEE TCAS·TCAD·TC·TVLSI 및 DAC·ICCAD·FPGA·FPL을 우선 검토하되 게재처와 실제 적용 가능성을 구분한다.
