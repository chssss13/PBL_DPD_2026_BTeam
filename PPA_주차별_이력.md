# PPA 이력표

[원본 양식](package/docs/ppa_history_template.md)의 열 순서와 v1 기준 0행을 사용한다. **1주차는 v0→v1**, **2주차는 v1 이후 최적화**다. v2 후보 중 여러 변경을 함께 적용한 행은 비고에 표시했다.

- 기능검증: `compare_out.py`의 참조 대비 NMSE와 PASS/FAIL. 양자화된 출력의 Q12 일치 여부는 별도로 확인했다.
- 정확도: `eval_pa.py`의 PA 통과 NMSE / ACPR L / ACPR R. 직접 평가하지 않은 행은 동일 벡터의 이전 PA 결과를 이어 쓴 것으로 표시한다.
- 처리율 = `1000 / (Post-Route 비교 주기 ns × II)`의 정상상태 추정치. 블록 호출 오버헤드 및 보드 실측은 포함하지 않는다.
- **0행은 v1**이다. 자원은 Vivado 배치·배선 후 값이며 개선률은 v1 대비다.
- 측정 환경: ☑ Windows PC  □ Linux PC/서버 / Vitis HLS·Vivado 2024.1 / `xczu7ev-ffvc1156-2-e`. 과거 실행 전체의 OS 세부 버전·CPU·메모리는 기록에서 동일하게 확인되지 않아 미기재.
- 공통 평가 입력은 7,680샘플, 상태 초기화 간격은 2,560샘플. 비교 주기는 주로 15ns 제약과 WNS로 환산했으며 최악 데이터 경로 지연과 구분한다.

| # | 날짜 | 변경 내용 (실험 ID) | 참조 대비 NMSE | PASS | PA NMSE / ACPR L / R | II | Post-Route (ns) | 처리율 (MSps) | LUT | FF | DSP | BRAM | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| v0 | 10/16 | [원본 (H=5, L=3)](result/00_v0/README.md) | −82.66dB | PASS | −26.67 / −39.48 / −36.09 | 2 | 17.129 | 29.19 | 46,646 | 49,546 | 648 | 0 | 1주차 출발점, PA·15ns 미달 |
| **0** | 10/29 | **[v1 기능 복구](result/07_lut_lookup/02_implementation/README.md)** | −196.85dB | PASS | −43.57 / −51.26 / −48.02 | 2 | 17.506 | 28.56 | 60,349 | 48,240 | 584 | 0 | **1주차 완료**, PA 통과·15ns 미달; RTL co-sim PASS |
| 1 | 11/02 | [보간 256구간 + data15,3·weight14,4](v2/result/ppa_evidence/09_interp_narrow/) | −196.50dB | PASS | −44.97 / −53.35 / −50.08¹ | 2 | 17.738 | 28.19 | 50,418 | 42,091 | 320 | 0 | 2주차; 보간·비트 축소 결합, 15ns 미달 |
| 2 | 11/02 | [recurrent 곱셈 게이트별 분리 (v2.4-S)](v2/result/v2.4-S/README.md) | −196.50dB | PASS | −44.97 / −53.35 / −50.08² | 2 | 17.524 | 28.53 | 47,575 | 41,799 | 333 | 0 | 15ns 미달 |
| 3 | 11/02 | [GRU 누산 21,6 확대](v2/result/ppa_evidence/11_accum_wide/) | −196.50dB | PASS | −44.97 / −53.35 / −50.08³ | 2 | 17.310 | 28.89 | 42,163 | 41,689 | 333 | 0 | 동일 벡터 PA 수치 이어 씀; 15ns 미달 |
| 4 | 11/02 | [recurrent 곱셈 항별 분리](v2/result/ppa_evidence/12_term_split/) | −196.50dB | PASS | −44.97 / −53.35 / −50.08³ | 2 | 16.427 | 30.44 | 41,735 | 41,383 | 337 | 0 | 동일 벡터 PA 수치 이어 씀; 15ns 미달 |
| 5 | 11/02 | [n recurrent 곱셈 행별 분리](v2/result/ppa_evidence/13_n_row_split/) | −196.50dB | PASS | −44.97 / −53.35 / −50.08³ | 2 | 15.266 | 32.75 | 41,806 | 41,161 | 347 | 0 | 동일 벡터 PA 수치 이어 씀; 15ns 미달 |
| 6 | 11/03 | [상태 갱신 z unsigned12,0](v2/result/ppa_evidence/14_z_unsigned12/) | −196.50dB | PASS | −44.97 / −53.35 / −50.08³ | 2 | 15.146 | 33.01 | 41,781 | 41,175 | 347 | 0 | 동일 벡터 PA 수치 이어 씀; 15ns 미달 |
| **7** | 11/03 | **[상태 결과의 최종 포화 생략 — v2 최종](v2/result/final/README.md)** | **−196.50dB** | **PASS** | **−44.97 / −53.35 / −50.08³** | **2** | **14.907** | **33.54** | **41,387** | **41,088** | **362** | **0** | 동일 벡터 PA 수치 이어 씀; **15ns 통과**, RTL co-sim PASS |

## 목표

| 구분 | 목표 | v2 최종 결과 |
|---|---|---|
| 정확도 (필수) | NMSE ≤ −43.48dB, ACPR ≤ −50.39 / −47.83dBc | 동일 벡터 출력 일치로 기존 PA −44.97 / −53.35 / −50.08과 연결³ |
| 처리율 | II=2, 66MHz (15ns) 타이밍 통과 → 33.3 MSps | II=2, WNS +0.093ns; 15ns에서 정상상태 약 33.33 MSps |
| 자원 (도전) | 같은 환경의 v0 수준 이하: LUT 46,646 / FF 49,546 / DSP 648 / BRAM 0 | LUT 41,387 / FF 41,088 / DSP 362 / BRAM 0 |

## 검증 및 수치 출처

- v0는 [팀의 Windows v0 결과](result/00_v0/README.md)다. 양식에 인쇄된 조교 참고값 46,544 / 49,551 / 648은 별도 측정이다. v0 기능 비교 PASS는 PA 정확도 PASS를 뜻하지 않는다.
- v1의 참조 NMSE는 7,680샘플 **RTL co-sim 출력 vs Python**, PA 값은 그 RTL 출력의 평가다. [v1 co-sim 결과](result/07_lut_lookup/01_cosim/README.md).
- v2 1~7행의 참조 NMSE는 각 단계의 기존 C-sim 출력과 해당 Python 참조 파일을 2026-11-05 `compare_out.py --nmse_max -60`으로 다시 비교한 값이다. 각각 7,680샘플 PASS. 출력 문자열 정밀도로 Q12 값은 같아도 텍스트상 작은 차이가 있어 약 −196.50dB가 나온다. [1](v2/result/ppa_evidence/09_interp_narrow/compare_out.txt) · [2](v2/result/ppa_evidence/10_gate_split/compare_out.txt) · [3](v2/result/ppa_evidence/11_accum_wide/compare_out.txt) · [4](v2/result/ppa_evidence/12_term_split/compare_out.txt) · [5](v2/result/ppa_evidence/13_n_row_split/compare_out.txt) · [6](v2/result/ppa_evidence/14_z_unsigned12/compare_out.txt) · [7](v2/result/ppa_evidence/15_state_nosat/compare_out.txt).
- ¹ 1행의 PA는 보간·축소 **Python 참조 출력** 평가 결과이며 C-sim과 Q12 일치한다. [PA 비교](v2/result/post_v2.3/accuracy/v1_interp_bit_comparison/pa_comparison.txt). ² 2행은 **C-sim 출력**의 PA 평가다. [v2.4-S PA 평가](v2/result/v2.4-S/accuracy/c_evaluation.txt).
- ³ 3~7행은 각 단계마다 PA 모델을 새로 실행한 수치가 아니다. 해당 7,680개 벡터의 C-sim 출력이 PA 평가한 2행 출력과 완전히 동일하므로 같은 PA 수치를 이어서 표시했다. [출력 파일 SHA-256 대조](v2/result/ppa_evidence/output_identity.json). 임의의 모든 입력에 대한 동등성을 의미하지 않는다.
- 최종 RTL co-sim은 11/05 동일 최종 소스를 **별도 재합성**해 Verilog/XSim으로 7,680샘플 PASS했다. [co-sim 결과·보고서](v2/result/final/reports/결과요약.md). 위 P&R은 기존 최종 구현 결과다. 보드 실측·외부 I/O 통합 타이밍은 미실시다.
- v1까지의 세부 과정과 미완료 후보는 [v1 의사결정과 합성 요약](v1_의사결정_합성요약.md), 2주차 변경 번호 9~15의 설명은 [채택 변경 이력](v2/result/final/docs/v1기반_채택변경_이력.md)에 있다. 각 P&R 근거는 행의 실험 링크에서 확인한다.

## v1 대비 최종 개선률

| 항목 | v1 | v2 최종 | 변화 |
|---|---:|---:|---:|
| Post-Route 비교 주기 | 17.506ns | 14.907ns | −2.599ns · −14.85% |
| 정상상태 처리율 추정 | 28.56 MSps | 33.54 MSps | +4.98 MSps |
| LUT | 60,349 | 41,387 | −18,962 · −31.42% |
| FF | 48,240 | 41,088 | −7,152 · −14.83% |
| DSP | 584 | 362 | −222 · −38.01% |
| BRAM | 0 | 0 | 변화 없음 |

## 2주차의 다른 출발점: v2.1~v2.3

다음은 **hyeonseo v1.7 기반의 별도 계보**다. 위 v1→v2.4-S의 직접 부모가 아니다. 모든 PA 수치는 각 C-sim 출력의 PA 평가이며 RTL co-sim은 미실시다.

| # | 날짜 | 변경 내용 (실험 ID) | 참조 대비 NMSE | PASS | PA NMSE / ACPR L / R | II | Post-Route (ns) | 처리율 (MSps) | LUT | FF | DSP | BRAM | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| v2.1 | 11/01 | [누산 폭·상태식·GRU tree](v2/result/v2.1/README.md) | −196.93dB | PASS | −43.66 / −51.92 / −48.52 | 2 | 21.287 | 23.49 | 70,412 | 48,482 | 636 | 0 | 변경 결합, 15ns 미달 |
| v2.2 | 11/01 | [512구간 선형 보간](v2/result/v2.2/README.md) | −196.88dB | PASS | −45.48 / −53.44 / −50.30 | 2 | 18.649 | 26.81 | 58,319 | 48,897 | 564 | 0 | 15ns 미달 |
| v2.3 | 11/01 | [비트 축소·256구간·중간 양자화](v2/result/v2.3/README.md) | −196.57dB | PASS | −45.11 / −53.02 / −49.87 | 2 | 18.105 | 27.62 | 56,671 | 43,367 | 305 | 0 | 변경 결합, 15ns 미달 |

여러 변경이 합쳐진 행은 개별 기여도를 분리하지 않았다. [v2.3 이후 시행착오](v2/v2.3_이후_실험정리.md).
