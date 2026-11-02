# v2.3 CE 단순화 진단 실험

- 기존 routed DCP를 읽고 복사본에만 적용. C++/HLS 프로젝트/원본 DCP/타이밍 제약 변경 없음.
- select_ln144_59_reg_160988_reg의 15개 CE 핀을 기존 LUT2 출력 대신 동일 stage1 제어 신호에 연결.
- LUT2 INIT=4'hE, LUT4 INIT=16'hA28A, 두 S 입력은 동일 드라이버. 16개 안정된 Boolean 입력 조합 모두 CE=S와 일치.
- 대상 레지스터의 CE 외 입력 연결 유지 확인. 전체 순차 등가 검증이나 타이밍 시뮬레이션은 수행하지 않음.
- 기존 배치를 유지하며 변경된 1개 신호만 재배선. 전체 P&R 재실행 아님.

| 항목 | 기존 | 변경 |
|---|---:|---:|
| 전체 WNS (ns) | -3.105 | -3.087 |
| 기존 대상 CE[2] setup slack (ns) | -3.105 | +14.063 |
| 새 최악 경로 끝점 | CE[2] | 같은 레지스터 뱅크 D[11] |

전체 WNS 개선은 약 0.018ns에 그침. 새 최악 경로 데이터 지연 18.067ns(논리8.809, 배선9.258), 논리70단. CE의 중복 연결 제거만으로 데이터 계산 경로가 해결되지 않음. 15ns 목표 미달 유지.

배선 오류 0. DRC error 없음; DSP 파이프라인 관련 경고 및 연결 대상이 사라진 net의 no-routable-load 경고 존재. 기존 OOC 클록/포트 관련 제약 한계도 유지됨.

II=2인 기존 HLS 스케줄의 회로를 사용했으며 파이프라인/연산기를 추가하지 않음. 수정 회로의 co-sim/실측 II는 별도 검증하지 않았으므로 최종 검증 완료판으로 취급하지 않음.

근거: proof.txt, changes.txt, route_status.rpt, timing_summary.rpt, ce_timing.rpt, drc.rpt. 출력 체크포인트: ce_simplified_routed.dcp.
