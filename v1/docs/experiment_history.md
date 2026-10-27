# v0 → v1 실험 순서

버전은 설계 후보와 구현 평가 흐름을 기준으로 v1.1~v1.7까지 연속으로 정리했다.
각 후보 문서는 Python 모사·C-sim·합성 등 해당 후보에서 수행한 검증을 함께 설명한다.
재학습이나 golden 변경은 없으며, 실제 측정값은 번호 변경으로 달라지지 않는다.

| 버전 | 내용 | 결과 위치 |
|---|---|---|
| v0 | 배포 원본 재현·정확도 평가·구현 | v0/results |
| v1.1 | golden에 가까운 초기 reference: Python 자료형 탐색 → C 구현·검증 | results/v1.1_reference/python_sweep 및 csim_reference |
| v1.2 후보 A | FEx 중간값·역수 모두 16,3: Python·C 검증, NMSE −45.06 | results/fex_comparison/python/fixed16_invI3.txt 및 csim/invI3 |
| v1.3 후보 B | 역수만 16,8: Python·C 검증, NMSE −45.48 → 합성 II=72 | results/fex_comparison/python/fixed16_invI8.txt 및 csim/invI8; results/v1.3_candidate_b/synthesis |
| v1.4 | 대칭 활성화 LUT, 정확도 통과, II=5 | results/v1.4_lut |
| v1.5 | 부호 포함 직접 조회 LUT, 정확도 통과, II=5 | results/v1.5_direct_lut |
| v1.6 | 동일 계산의 스케줄 조정, II=2, 전체 RTL co-sim PASS | results/v1.6_schedule |
| v1.7 | v1.6 회로의 Vivado 배치·배선 및 PPA 평가, 15 ns 타이밍 미달 | results/v1.7_implementation |

후보 A/B의 공통 모사·평가 스크립트는 results/fex_comparison에 결과를 함께 저장한다.
개별 원시 파일·소스 사본의 대응은 [후보 A](v1.2_candidate_a.md), [후보 B](v1.3_candidate_b.md)를 따른다.
각 결과 폴더는 당시 결과와 소스 사본이며 독립적인 전체 프로젝트 복사본은 아니다.

## 과거 명칭 대응

과거 로그·보고서·소스 사본의 명칭과 절대경로는 수정하지 않고 보존한다.
문서·결과 폴더·현재 스크립트 경로는 새 번호로 갱신했다.

| 과거 실험/버전 | 현재 버전 |
|---|---|
| E01 / 구 v1.1 Python 탐색 | v1.1 Python 단계 |
| E02 / 구 v1.2 C 참조 검증 | v1.1 C 단계 |
| E03 / 구 v1.3 두 후보 모사 | v1.2 후보 A + v1.3 후보 B의 Python 단계 |
| E04 / 구 v1.4 두 후보 C 검증 | v1.2 후보 A + v1.3 후보 B의 C 단계 |
| E05 / 구 v1.5 합성 | v1.3 후보 B 합성 단계 |
| E06 / 구 v1.6 | v1.4 |
| E07 / 구 v1.7 | v1.5 |
| E08 / 구 v1.8 | v1.6 |
| E09 / 구 v1.9 | v1.7 |

prj_e07은 현재 v1.5, prj_e08은 현재 v1.6 합성/RTL 및 v1.7 구현에 해당한다.
이 프로젝트 이름은 빌드 재사용을 위해 바꾸지 않았다. Git에는 전체 빌드 프로젝트 대신 필요한 보고서와 소스를 보관했다.

## 재현과 현재 상태

Vitis HLS 2024.1 Command Prompt에서 `scripts/run_ii2_candidate.cmd`로 v1.6을 합성한다.
기본 run_resgru.tcl 실행과 성공 후보 설정은 다르다.
RTL 검증은 `vitis_hls -f scripts/cosim_existing.tcl`, 구현은 `vitis_hls -f scripts/impl_existing.tcl`로 이어간다.

v1.6의 정확도·II=2·전체 RTL 검증은 통과했지만, v1.7에서 15 ns 물리 타이밍은 실패했다.
최종 결과와 한계는 [초기 reference](v1.1_reference.md), [후보 A](v1.2_candidate_a.md),
[후보 B](v1.3_candidate_b.md), [LUT와 스케줄 탐색](v1.4_v1.6_search.md),
[구현·PPA](v1.7_implementation.md), [PPA 이력표](ppa_history_template.md)를 참고한다.
