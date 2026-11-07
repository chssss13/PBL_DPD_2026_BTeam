# C03 준비 — r unsigned12

2026-11-05. 부모는 v2 최종 채택본(`v2/result/final`), BRAM 후보와 별도 분기다.

- 목적: r 값과 정확도를 유지하면서 곱셈 입력 폭을 줄여 자원 절감 가능성을 확인한다.
- DUT 변경은 `src/gru_cell.h`의 `r * (W_hn_h[i] + b_hn_local[i])` 한 곳이다. r을 `ap_ufixed<12,0>`으로 복사해 곱하며, 합·최종 반올림/포화·z와 상태 갱신은 유지한다. `source.diff` 참고.
- Python 사전 확인: 현재 sigmoid 표에 대한 입력 32,768개 모두 r의 Q12 정수값이 74~4,022이다. 하위 12비트로 표현한 값과 불일치 0개. `r_gate_range_audit.json` 참고.
- 산술 근거: 피승수 합은 소수 15비트, 범위 [-8,8)이며 r은 [0,1)이다. 곱셈의 소수 27비트와 해당 값 범위를 두 자료형 모두 표현하면 정확한 곱은 같고, 동일한 최종 형식으로 변환한 값도 같다. 설치된 HLS 자료형의 실제 폭은 테스트벤치 static_assert와 실행 로그로 확인한다.
- 테스트벤치에 전체 sigmoid 입력의 값 보존 검사와 곱셈 경계값 검사를 추가했다. 그 뒤 기존 7,680개 네트워크 입력을 실행하고 최종 C-sim/Python 참조와 Q12 일치를 확인한다. 실패하면 csynth를 실행하지 않는다.
- 실행: 해당 폴더 `run.cmd`. 진행은 `status.txt`, `csynth.log`, 종료는 `exit_code.txt`에서 확인한다. 기존 프로젝트가 있으면 초기화하지 않고 중단한다.
- 조건: Vitis HLS 2024.1, xczu7ev-ffvc1156-2-e, 15ns, uncertainty 1ns, LOOP_T II=2 요청, DSP full reg false.
- 최초 요청은 C-sim·csynth까지였으며, 완료 후 사용자 요청으로 P&R도 실행했다(`pnr_run.json`). PA 재평가·RTL co-sim은 수행하지 않는다.

## 실행 확인

- C-sim 완료, 오류 0개. 7,680개 출력에서 최종 C-sim과 최대 오차 0, Python 참조와 Q12 불일치 0개(`csim_comparison.json`).
- csynth 완료, 종료 코드0. LOOP_T II2/Depth18, 추정 주기13.881ns. HLS LUT221,755/FF127,920/DSP489/BRAM0. v2 최종본 대비 LUT615개·FF60개 감소. [C03 결과 기록](../../../result/c03_r_unsigned12/README.md).

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
