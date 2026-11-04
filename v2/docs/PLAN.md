# v2 순차 실험 계획

현재 결과: v2.2 채택, v2.3/v2.4 폐기, 식 변형은 v3.1로 이관 후15ns 실패로 폐기했다.
추가 실험은 실행하지 않는다. 최신 버전별 설정·지표는 [상세 이력](experiment_history.md)을 기준으로 삼는다.
아래의 진행·예정 표현은 당시 계획 이력이다.

최신 분류: 식 변형 후보는 [v3.1](../../v3/README.md)로 이동한다.
아래 새 v2.5 표기는 기존 실행 이력이며 v2의 채택 버전은 v2.2다.

최신 사용자 지시: 호출 오버헤드는 목표 판정에서 제외한다. 현재 진행 중인
새 v2.5 식 변형의 정확도·II·15 ns 타이밍·자원 지표까지만 제시하고 추가 실험은 하지 않는다.
아래 호출 오버헤드 관련 내용은 이전 실험 이력이며 현재 합격 조건이 아니다.

사용자 요청으로 [hidden state 식 재구성](HIDDEN_STATE.md)을 새 v2.5 후보에 추가했다.
개선이 없었던 v2.3/v2.4는 폐기했다. v2.2를 기반으로 식만 바꿔 평가한다.

후속 요청으로 호출 오버헤드 최적화를 재개했다. 후속 계획은
[CALL_OVERHEAD.md](CALL_OVERHEAD.md)가 아래의 조건부 계획과 보류 결정을 대체한다.

기존 v2 실험은 종료하고 삭제했다. 과거 v2.5는 별도 `repro_v2_5`에 보존한다.
새 번호는 과거 번호와 의미가 다르다. v1 원본은 수정하지 않는다.

## 고정 조건

- Vitis HLS/Vivado 2024.1, xczu7ev-ffvc1156-2-e.
- 실제 구현 클록 15 ns, uncertainty 1 ns, DSP full register false.
- LOOP_T 실제 II ≤ 2. II를 늘려 정확도를 맞추지 않는다.
- data_t 16/3, weight_t 16/4, accum_t 32/12, AP_RND/AP_SAT 유지.
- H=5, 입력 크기 5, 3층, 64샘플 호출, 7680샘플 검증, 2560샘플마다 reset.
- FEx 고정소수점 중간값과 16/8 역수, DIRECT_LUT_SHIFT=4 유지.
- PA NMSE ≤ -43.48 dB, ACPR L/R ≤ -50.39/-47.83 dBc.
- hw_ref와 C 및 RTL 출력의 16비트 단어 일치와 compare_out PASS 필수.
- routed setup/hold slack ≥ 0, routing error 및 미배선 net 0 필수.

## 버전별 변경

| 버전 | 단일 도입 변경 | 확인할 개선 |
|---|---|---|
| v2.1 | 직접 activation LUT를 latency=1 BRAM ROM으로 전환 | 큰 조합 mux 경로 제거, II/지연 영향 |
| v2.2 | v2.1에 포화 MAC의 균형 트리 추가 | 누적 덧셈 경로 단축; 과거 v2.5의 활성 개선 조합 |
| v2.3/v2.4 | 호출 제어 변경 실험 후 폐기 | 처리율·지연·HLS 자원 개선 없음 |
| 새 v2.5 | v2.2에서 hidden state 식만 재구성 | 곱셈 수 감소 효과를 정확도·II·타이밍·처리율로 검증 |

후속 후보는 결과 검토 후 한 개씩 실행한다. 현재 새 v2.5를 진행한다.
트리는 포화 덧셈 순서를 바꾸므로 수학적 동등성을 가정하지 않고 후보별 참조를 재생성한다.

## 실행 및 판정 순서

`C:/Project/venv_dpd/Scripts/python.exe v2/scripts/run_version.py v2.1`

소스/TB 스냅샷 및 해시 → Python 참조 → C sim → 단어/compare_out/PA 검증 →
합성 및 실제 LOOP_T II 판정 → 전체 RTL cosim 및 동일 검증 → 15 ns 배치배선 →
실제 routed setup/hold/route status 판정 → 직전 버전 대비 검토 순서다.
한 번에 한 버전만 실행한다. 수치 또는 II 실패는 구현 전에 중단한다.
타이밍 실패는 원인과 수치를 남기고 다음 변경의 근거로 사용한다.
미실행·증거 없음은 PASS로 처리하지 않는다. 실패한 변경은 채택하지 않는다.
결과 파일을 덮어쓰지 않으며 중단 후에는 `--resume`으로 완료 단계를 이어간다.

호출 오버헤드는 현재 최적화 범위에서 보류했다. II=2,15 ns의 정상상태는
33.333 MSps지만, 과거 v2.5의 64샘플 호출 간격 134cycle 기준은 31.841 MSps다.
따라서 순수 타이밍 PASS와 오버헤드 포함 33.3 MSps 달성을 구분해 보고한다.

## 참고 및 적용 한계

- [AMD bind_storage](https://docs.amd.com/r/2024.1-English/ug1399-vitis-hls/pragma-HLS-bind_storage): ROM 구현과 latency 지정.
- [hls4ml recurrent neural networks](https://arxiv.org/abs/2207.00559): 순환망 HLS 구조와 재귀 경로의 배경.
- [Remarn](https://doi.org/10.1145/3534969): 재귀 연산 및 균형 연산 구조 검토의 배경.

논문의 성능 수치를 본 설계에 대입하지 않는다. 채택 여부는 본 FPGA의 실제 보고서로 정한다.
