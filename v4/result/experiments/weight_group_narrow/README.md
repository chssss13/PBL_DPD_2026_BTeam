# 별도 실험 — 가중치 그룹별 비트폭 축소

부모는 [v4.4 면적 옵션](../../v4.4/README.md)이다. FEx 역제곱근 BRAM 조회, FIFO 깊이 1 및 채널 그룹별 제어 공유를 유지했다. 2026-11-16 기록에서는 이 실험을 v4.3으로 표기했다. 현재 버전 순서에서 [v4.3](../../v4.3/README.md)은 기존 깊이 2 FIFO에 제어 공유를 적용한 단계다.

## 변경

| 대상 | 부모 | 가중치 축소 |
|---|---:|---:|
| Input FC `W_inj` | 14/4 | 12/2 |
| Output FC `W_out` | 14/4 | 11/1 |
| GRU 입력 `W_in` | 14/4 | 11/1 |
| recurrent `W_hn` | 14/4 | 12/2 |
| recurrent `W_hr`, `W_hz` | 14/4 | 13/3 |

전체/정수부 표기이며 모두 소수부 10비트를 유지한다. W_ir, W_iz, bias, gating, PReLU 계수와 data_t는 변경하지 않았다. 곱 결과와 누산의 양자화 위치는 유지한다. 좁은 형식은 현재 양자화된 모델 가중치를 모두 표현하지만, 더 넓은 원래 인터페이스 범위의 임의 가중치를 허용한다는 뜻은 아니다.

## 정확도와 검증

동일 7,680샘플·2,560샘플 상태 리셋 조건. 후보 C-sim은 부모의 HLS C-sim 및 Python 참조와 Q12 불일치 0, 변환 RTL co-sim은 후보 C-sim과 Q12 불일치 0이다. 후보의 PA 수치는 동일 출력에 대응하는 부모 평가값이다.

| 지표 | golden | v4.1 | 부모 | 가중치 축소 |
|---|---:|---:|---:|---:|
| NMSE (dB) | -45.52 | -45.03 | -45.19 | -45.19 |
| EVM (dB) | -49.42 | -48.78 | -48.90 | -48.90 |
| ACPR L (dBc) | -53.59 | -53.51 | -53.43 | -53.43 |
| ACPR R (dBc) | -50.43 | -50.38 | -50.25 | -50.25 |

HLS LOOP_T II 2, RTL co-sim 지연 143클록·호출 간격 134클록. 부모 FIFO 후보 co-sim의 지연은 144클록, 호출 간격은 134클록이다. 이 결과는 제공 입력과 테스트 호출 조건에 대한 검증이다.

## 결과

Vitis HLS/Vivado 2024.1, xczu7ev-ffvc1156-2-e, 목표 15 ns, HLS uncertainty 1 ns, Vivado AreaOptimized_high. BRAM은 36Kb 타일이고 비교 주기는 15−WNS다. 최종 타이밍 및 자원은 P&R 결과다.

| 항목 | 부모 | 가중치 축소 | 변화 |
|---|---:|---:|---:|
| LUT | 25,663 | 24,174 | -1,489 (-5.8%) |
| FF | 29,372 | 26,307 | -3,065 (-10.4%) |
| DSP | 347 | 417 | +70 (+20.2%) |
| BRAM 타일 | 7.5 | 7.5 | 0 |
| WNS (ns) | +0.107510 | +0.0718 | 약 -0.0357 |
| 비교 주기 (ns) | 14.892490 | 14.9282 | 약 +0.0357 |

후보의 WNS는 구현 로그가 제공하는 정밀도다. setup·hold 위반과 미배선은 0이다. FIFO 제어와 페이로드를 변환한 RTL을 co-sim과 구현에 사용했고 설치 RTL 일치를 확인했다. 일반 곱셈기 그룹의 DSP가 144→214로 늘었으며 recurrent 전용 그룹은 동일해, 가중치 폭 분리 뒤 일반 곱셈기 공유 변화가 유력한 원인이다. 여러 그룹을 동시에 바꿨으므로 개별 그룹의 기여도는 분리되지 않았다.

HLS 원본 RTL의 추정값은 LUT 180,604 / FF 110,335 / DSP 499 / BRAM_18K 14, 추정 주기 13.960 ns다. FIFO 변환 전 추정치이므로 P&R 자원과 직접 혼동하지 않는다.

## 자료

- [소스](src/), [테스트벤치](tb/), [C-sim 비교](reports/csim_comparison.json), [RTL co-sim](reports/ResGRU_cosim.rpt), [출력 비교](reports/cosim_comparison.json).
- [HLS 보고서](reports/ResGRU_csynth.rpt), [P&R 자원](reports/utilization.rpt), [타이밍](reports/timing_summary.rpt), [구현 로그](reports/impl.log), [RTL 설치 검증](reports/implementation_rtl_audit.json).
- [실행 당시 스크립트 스냅샷](scripts/)은 경로와 부모 프로젝트에 의존한다. 이 보관 폴더의 독립 재합성은 검증하지 않았다. FIFO 변환을 생략한 HLS 출력은 검증한 RTL과 다르다.
- 실행 원본은 `v3/package/results/v35_fullrom_weight_groups_csim`이며 기존 결과를 보존했다.
