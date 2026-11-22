# PPA 이력표

기존 [PPA 이력표 양식](v0/docs/ppa_history_template.md)의 열 구성을 유지하고, **v0 → main의 v1·v2·v3·v4 최종본**만 채웠다. 여러 변경을 누적한 버전별 최종 결과 비교이며, 단일 변경 실험표는 아니다.

- 기능검증: `compare_out.py` 결과 또는 보관된 Q12 출력 비교·RTL co-sim 결과. 숫자 NMSE가 없는 기록은 Q12 불일치 수로 표시한다.
- 정확도: PA 통과 NMSE / ACPR L / ACPR R, 단위 dB / dBc / dBc.
- 처리율 = Fmax / II (MSps). 아래는 `1000 / Post-Route(ns) / II`로 계산한 정상상태 환산이며 호출 오버헤드·보드 실측은 제외한다.
- **개선률 기준은 첫 행 v0**다. v1은 현서 v1.7, v2는 main의 v2.4, v3는 v3.3, v4는 v4.7이다.
- 모든 HW 수치는 실제 배치·배선 후 값이다. v0는 조교 참고값 대신 팀 구현값을 사용한다. 주기는 15 ns 제약에서 WNS로 환산한 비교 주기다.
- 측정 환경: Windows PC / Vitis HLS·Vivado 2024.1 / `xczu7ev-ffvc1156-2-e`. v0·v1은 `DESKTOP-TCLI4QB`, v2~v4 보고서는 `DESKTOP-ECCJF6L`이다. CPU·메모리는 미기록이며, v0 uncertainty 4.05 ns와 이후 1 ns 등 제약·합성 옵션 차이가 있다. 동일 환경·동일 제약에서 재측정한 비교는 아니다.

| # | 날짜 | 변경 내용 (실험 ID) | 참조 대비 NMSE | PASS | PA NMSE / ACPR L / R | II | Post-Route (ns) | 처리율 (MSps) | LUT | FF | DSP | BRAM | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| v0 | 2026-10-16 | 원본 (config 5,3), 팀 PC 구현 | −82.66 dB | C/Python PASS | −26.67 / −39.48 / −36.09 | 2 | 17.129 | 29.19 | 46,646 | 49,546 | 648 | 0 | 비교 기준; 정확도·15 ns 타이밍 미달 |
| v1 | 2026-10-16 | 현서 v1.7 최종: 정확도 복구·LUT 활성화·II=2 | −196.93 dB (RTL/Python) | C/Python·C/RTL PASS | −43.67 / −51.82 / −48.38 | 2 | 24.054 | 20.79 | 66,859 | 49,754 | 711 | 0 | 정확도 통과, 15 ns 타이밍 실패; WNS −9.054 ns |
| v2 | 2026-11-03 | main v2.4 최종: state_nosat·누산·곱셈 분리·상태 갱신 개선 | NMSE 미기록; Python 참조 Q12 불일치 0 | C-sim·RTL co-sim PASS | −44.97 / −53.35 / −50.08 | 2 | 14.907 | 33.54 | 41,387 | 41,088 | 362 | 0 | 정확도·15 ns 통과; WNS +0.093 ns; PA는 기존 벡터 출력 일치로 연결 |
| v3 | 2026-11-07 | main v3.3 최종: sigmoid 대칭표·recurrent 곱 포화 제거·r/z bias 사전 합산 | NMSE 미기록; Python 참조 Q12 불일치 0 | C-sim PASS; RTL co-sim 미실시 | −44.97 / −53.35 / −50.08 | 2 | 14.910 | 33.53 | 37,419 | 38,575 | 362 | 0 | 정확도·15 ns 통과; WNS +0.089846 ns; PA 재평가 미실시 |
| v4 | 2026-11-20 | main v4.7 최종: FEx ROM·FIFO 개선 및 GRU 2층 가중치 150개 전달 경로 단축 | 부모와 I/Q 15,360개 일치 | RTL 7,680샘플·가중치 변경 4회 호출 PASS | −45.19 / −53.43 / −50.25 | 2¹ | 14.949 | 33.45¹ | 20,069 | 19,200 | 347 | 7.5² | 정확도·15 ns 통과. WNS +0.051 ns. PA는 v4.2부터 이어진 출력 일치에 근거 |

¹ v4.7은 II=2인 v4.2 HLS 생성 RTL을 후처리한 구현이다. II와 처리율은 기준 샘플 루프에 따른 환산이며 후처리 RTL의 새로운 HLS 측정값이 아니다. co-sim 호출 지연 144클록·호출 간격 134클록은 샘플 II와 구분한다.

² BRAM은 36 Kib 타일 기준이며 7.5타일은 RAMB36 7개 + RAMB18 1개다. SRL은 LUT에 포함되므로 추가 합산하지 않는다. 전력·보드 처리율·외부 I/O 통합 타이밍은 미측정이다.

v0 C/Python 기능 비교는 기존 출력으로 2026-10-27 확인한 로그다. 날짜 열은 구현 보고서 날짜이며 모든 검증을 같은 날 실행했다는 뜻은 아니다. v2.4 최종의 별도 재합성 RTL co-sim은 2026-11-05 수행했다. 같은 벡터의 출력 일치에 연결한 PA 값은 각 최종본에서 PA 모델을 새로 실행한 결과와 구분한다.

## 목표

| 구분 | 목표 |
|---|---|
| 정확도 (필수) | NMSE ≤ −43.48, ACPR ≤ −50.39 / −47.83 |
| 처리율 | II = 2, 66 MHz (15 ns) 타이밍 통과 → 33.3 MSps |
| 자원 (도전) | 팀 v0 수준 (LUT 46,646 / FF 49,546 / DSP 648) 이하 |

## 근거

- v0·v1: [팀 PPA 이력](v1/docs/ppa_history_template.md), [v0 구현](v1/results/E00_v0_implementation/export_impl.rpt), [v0 기능 비교](v0/results/compare_v0.txt), [v1 최종 구현](v1/docs/v1.7_implementation.md).
- v2: [최종 결과·검증](v2/result/v2.4/reports/결과요약.md), [P&R 자원](v2/result/v2.4/reports/pnr/utilization.rpt), [타이밍](v2/result/v2.4/reports/pnr/timing_summary.rpt).
- v3: [v3.3 결과·검증](v3/result/v3.3/README.md), [P&R 자원](v3/result/v3.3/reports/utilization.rpt), [타이밍](v3/result/v3.3/reports/timing_summary.rpt).
- v4: [v4.7 결과·검증](v4/result/v4.7/README.md), [PA·버전 비교](v4/README.md), [P&R 자원](v4/result/v4.7/reports/utilization.rpt), [타이밍](v4/result/v4.7/reports/timing_summary.rpt).
