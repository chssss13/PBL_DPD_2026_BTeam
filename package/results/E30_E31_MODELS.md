# 논문 적용 모델 E30·E31

두 후보 모두 원본 v3.4에서 독립 생성했고 C-sim/RTL/P&R까지 완료했다. 미채택 실험이며 원본 v3.4는 유지한다.

| 모델 | 적용 원리 | 결과 |
|---|---|---|
| [E30 / v3.4-3](E30_v3_4_3_fpgai_output_share/README.md) | FPG-AI RNN의 출력 Dense 우선 자원 조정 | 정확도·II2·15ns 유지. LUT/FF 감소, DSP +5. 의도한 5개 곱셈 공유 미달성 |
| [E31 / v3.4-4](E31_v3_4_4_flexpwl/README.md) | FlexPWL의 POT slope + MXE offset | II2·15ns 유지. PA 정확도 저하, LUT +83/FF −265 |

AERO/E28 및 RMRA/E29 소스는 이 커밋의 대상이 아니다. 각 폴더 README에 적용 범위·평가 수치·재현 조건을 기록했다.
