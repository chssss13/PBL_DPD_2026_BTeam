# v0 기본 합성 설정에서 II=2를 위한 구조 탐색

## 비교 조건

v0의 Tcl과 동일하게 `xczu7ev-ffvc1156-2-e`, 목표 클록 15 ns를 사용한다. `config_schedule`, `set_clock_uncertainty`, 외부 pipeline II override를 추가하지 않는다. 보고서에서 기본 uncertainty 4.05 ns를 확인한다. 소스의 기존 pipeline/partition 지시는 유지하고 후보별 C 구조만 바꾼다. 소스의 INLINE/UNROLL은 아래에 변경 내역을 명시한다.

정확도 조건은 입력 `<16,3>`, 가중치 `<16,4>`, 누산기 `<32,12>`, FEx 역수 `<16,8>`, 초기화 간격 2,560샘플이다. 활성화는 개선된 직접 LUT 1/2048로 고정한다. 따라서 이전 v1.5의 1/512 수치와 자원 차이 전부를 이번 구조 변경의 효과로 해석해서는 안 된다. 기존 기본 소스와 프로젝트는 덮어쓰지 않는다.

## v0에서 참고한 점

v0와 v1의 GRU 상태 갱신식 및 MAC 루프 골격은 같다. v0는 hard 활성화 및 `<18,3>` 누산기를 사용하지만, 정확도가 부족하므로 그대로 되돌리지 않는다. v1.5 로그는 상태 갱신식의 연산을 DSP latency 3으로 배치했다고 명시한다. 따라서 먼저 이 식의 곱셈 수와 구현 구조를 변경한다. 더 넓어진 누산기와 LUT 조회도 재귀 경로에 영향을 줄 수 있다.

## 후보

1. `state_logic`: `(1-z)*n + z*h`를 `n + z*(h-n)`으로 정리. 16비트 원시 정수 표현에서 시프트와 균형 덧셈 트리로 곱셈을 기술하고, 마지막에 AP_RND/AP_SAT와 같은 반올림·포화를 적용한다. 중간 결과는 정밀도를 유지하도록 넓힌다. DSP binding이나 지연 지시를 추가하지 않는다.
2. `state_reset_logic`: 첫 후보에 더해 `r*(W_hn_h+b_hn)`의 곱셈도 시프트·덧셈 트리로 기술한다. 원래 식의 소수부를 유지한 뒤 data_t에 양자화한다.
3. `inline_lut`: 두 번째 후보의 LUT 함수를 INLINE하여 함수 경계를 없앤다. 기존 INLINE off와 LATENCY=0 요청을 제거한다. 표 값·입출력 계산은 같다. v0의 단순 활성화 함수처럼 호출 경계를 통합할 효과를 확인한다.

시프트·덧셈 기술이 실제 DSP를 전혀 사용하지 않는다고 단정하지 않는다. HLS가 다시 최적화할 수 있으며 최종 보고서로 확인한다. 은닉 상태 의존성 제거 지시나 시퀀스 interleaving은 사용하지 않는다.

## 현재 확인 결과

| 후보 | C-sim | C/Python NMSE | PA NMSE | PA ACPR L/R | achieved II | HLS clock | HLS LUT / FF / DSP |
|---|---|---:|---:|---|---:|---:|---|
| state_logic | 7,680샘플 완료 | −196.94 dB, PASS | −45.34 dB | −53.69 / −50.32 dBc | 3 | 10.840 ns | 233,234 / 146,109 / 385 |

첫 후보는 정확도 세 기준을 만족하지만 II=2에는 미달한다. 위 clock과 자원은 HLS 추정이며 물리 구현 결과가 아니다. 실제 C 출력 비교는 전체 테스트에서의 확인이며 모든 입력 조합에 대한 동치 증명은 아니다.

2026-10-27 사용자의 전체 중단 요청에 따라 `state_reset_logic`과 `inline_lut` 합성을 종료했다. 두 후보의 C-sim은 완료됐지만 합성은 미완료이므로 II·자원 결과를 제시하지 않는다. `state_reset_logic/compare.txt`에는 C/Python −196.94 dB PASS가 보존돼 있다. 기본 `v1/src`에는 이 구조 탐색을 반영하지 않았으며 후속 실행도 중단 상태다.

## 재현과 근거

v1 폴더의 Vitis HLS 2024.1 Command Prompt에서 실행한다.

```bat
set ARCH_CASE=state_logic
vitis_hls -f scripts/run_default_schedule_search.tcl
```

후보별 소스·TB·출력·로그는 `results/default_schedule/<후보>/`에 보관한다. 프로젝트는 `prj_default_<후보>`로 분리한다. 첫 후보의 보고서는 `state_logic/report/`, 비교는 `compare.txt`, PA 평가는 `c_evaluation.txt`에 있다. RTL co-sim 및 배치배선은 아직 실행하지 않았다.
