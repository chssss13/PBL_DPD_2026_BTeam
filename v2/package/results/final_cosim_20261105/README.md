# 최종 채택본 RTL co-sim 실행

## 완료 결과

2026-11-05 Verilog/XSim co-sim **PASS**, 프로세스 종료 코드 0. RTL 출력 7,680개가 기존 최종 C-sim 출력과 완전히 일치했다. 저장된 Python 참조와 Q12 불일치도 0개다(텍스트 출력 정밀도에 따른 최대 오차 5e-11).

- 최상위 64샘플 호출 latency 147클록, 호출 interval 134클록, 총 16,093클록. 호출 interval은 샘플 루프 II와 다르다.
- 재생성한 Verilog 65개를 기존 최종 RTL과 대조했으며, 주석·공백을 제외한 텍스트 차이는 0개였다. [대조 결과](rtl_identity_comparison.json).
- 기준 실험 파일 1,291개는 시작 전 해시와 모두 일치했다. 기존 P&R 결과는 변경하지 않았다.
- co-sim 보고서 (로컬 보존: `prj/sol1/sim/report/ResGRU_cosim.rpt`), [출력 비교](rtl_comparison.json).

2026-11-05 사용자 요청으로 시작했다. 완료 여부는 `status.txt`, `exit_code.txt`, `cosim.log`와 실제 co-sim 보고서를 확인한다. 이 문서의 생성은 검증 통과를 뜻하지 않는다.

- 기준: `../v1_gru_accum_wide_z_unsigned12_state_nosat_csynth/`.
- DUT 13개 파일은 기준 소스 및 `v2/result/final/src/`와 SHA-256이 일치한다.
- 테스트벤치 변경은 Windows `_setmaxstdio(2048)` 설정뿐이다. [실제 차이](testbench.diff).
- 기존 HLS 내부 중간 파일이 정리되어 별도 프로젝트에서 동일 설정으로 csynth를 다시 수행한다. 기존 P&R은 재실행하지 않는다.
- 순서: C-sim → 기존 C-sim/Python 참조와 Q12 비교 → csynth → Verilog/XSim RTL co-sim → RTL 출력과 두 참조의 Q12 비교.
- 입력 7,680개, 64샘플 블록 120회, 2,560샘플마다 상태 리셋. 입력·가중치는 공개 최종 보관본의 `golden/`을 사용한다.
- 클록 15ns, uncertainty 1ns, DSP full reg false, LOOP_T II=2 요청, Vitis HLS 2024.1.
- `parent_preservation_sha256.json`은 시작 전 기준 실험 파일 1,291개의 해시다. 기준 결과를 변경하지 않는다.

## 결과 확인 위치

- [통합 로그](cosim.log), [현재 단계](status.txt)
- `csim_comparison.json`: 새 C-sim과 기존 두 참조 비교.
- `prj/sol1/sim/report/ResGRU_cosim.rpt`: RTL co-sim PASS/FAIL와 호출 latency/interval.
- `rtl_out.txt`, `rtl_comparison.json`: RTL 출력과 두 참조의 Q12 비교.
- `prj/sol1/syn/verilog/`: 이번 co-sim 대상 RTL. 기존 최종 RTL과 대조할 때 경로·생성일 주석과 실제 논리를 구분한다.

이번 검증은 HLS가 생성한 RTL의 기능 검증이다. 기존 routed netlist의 타이밍 시뮬레이션이나 PA 신경망 재평가, 보드 실측은 아니다.
