# 논문 기반 후속 후보

## 최종 상태: 순차 도입 완료, v3.5 채택

2026-11-11. 현재 최종본은 v3.5: LUT 37,311 / FF 41,308 / DSP 355 / BRAM 0, II=2, 실제 주기 14.893 ns다. v3.4 면적 합성 설정과 v3.5 recurrent 곱 포화 제거를 채택했다. sigmoid 대칭 교체는 자원 기준 미달, bias 사전 합산은 15.678 ns로 timing 미달하여 삭제했다. 아래의 ‘현재 실행’·‘설정 비교 실행’ 표현은 이전 계획 기록이며 모두 종료됐다. 현재 실행·예약 작업은 없다. [최종 결과](../results/v3.5/RESULTS.md) · [단계별 판정](../results/batch/sehyeon_sequence.json).

2026-11-10 사용자 요청에 따라 우리 채택본 v3.3에서 출발해 sehyeon `176b59b`의 sigmoid 대칭 표, AreaOptimized_high, recurrent 곱 포화 제거, r/z bias 사전 합산을 순차 검증한다. 첫 후보는 v3.4이며 한 번에 한 방식만 추가한다. 개선 기준 미달은 삭제하고 마지막 채택본에서 다음 방식을 시작한다. 이전 통합 후보의 결과를 계승하지 않는다. [진행 조건과 실행기](PLAN.md) · [공통 진행 기록](../results/batch/sehyeon_sequence.json).

아래 구조 후보·설정 비교 기록은 이전 작업이다. 그 작업이 현재 예약되어 있다는 뜻은 아니다.

2026-11-10. 현재 채택본은 v3.3이다. LUT 39,854 / FF 41,222 / DSP 355 / BRAM 0, II=2, 실제 주기 14.897 ns다. 외부 I/Q·가중치 입력·호출 방식을 유지한다. IEEE TCAS·TCAD·TC·TVLSI 및 DAC·ICCAD·FPGA·FPL 원문을 우선 검토한다.

**두 구조 후보 실행 완료:** `scripts/run_structure_search.py`가 후보 1 → 후보 2의 전체 flow를 순차 실행했다. 둘 다 자원 개선 채택 기준 미달로 소스·결과·상세 문서를 삭제했으며 기준 채택본은 v3.3이다. 실행 근거는 `results/batch/structure_search.log`다. 이번 두 후보의 실제 자원 수치는 삭제 전에 공통 로그에 남기지 못했으므로 소급해 추정하지 않는다. 이후 실행기는 삭제 전 `FINAL_METRICS`를 공통 flow 로그에 출력하도록 수정했다.

**마지막 설정 비교 실행:** 사용자 요청으로 `scripts/run_synthesis_search.py`가 동일 v3.3 소스·HLS RTL에 `AreaOptimized_high` → `AreaOptimized_medium`을 각각 적용한다. 둘은 같은 부모의 독립 대안이며 누적하지 않는다. C·PA·HLS·RTL 검증은 동일 소스·RTL의 기존 결과를 계승하고 Vivado 합성·배치배선만 새로 수행한다. 이 설정 실험은 세현의 방식과 겹치며 새 논문 기법으로 포장하지 않는다. II=2·15 ns·입력·HLS uncertainty와 기존 채택 기준을 유지한다. 통과본은 보존하고 미달 후보는 실제 삭제한다. 최종 수치는 `results/batch/synthesis_search.log`의 `FINAL_METRICS`에 남긴다. 두 설정 이후 추가 실행은 예약하지 않는다. [AMD 2024.1 공식 설정](https://docs.amd.com/r/2024.1-English/ug901-vivado-synthesis/Using-Synthesis-Settings).

## 완료 상태

| 항목 | 상태 |
|---|---|
| FEx inverse 정밀도 재배분 | [v3.1 채택](../results/v3.1/RESULTS.md) |
| 보정 seed·정규화 NR 1회 | [v3.2 채택](../results/v3.2/RESULTS.md) |
| sigmoid multipartite | [v3.3 채택](../results/v3.3/RESULTS.md) |
| scalar FIFO 깊이 2→1 | 생성 RTL 깊이가 바뀌지 않아 제외·삭제 |
| tanh 무손실 twofold band 8·16 | 두 대안 모두 전체 flow 후 자원 기준 미달·삭제 |

실패한 후보는 현재 소스·결과·상세 문서로 보관하지 않는다. 위 표는 다음 후보 선정에서 같은 실험을 반복하지 않기 위한 최소 상태 기록이다. 현재 실행은 아래의 새 구조 후보 두 가지이며 위 실패 실험을 반복하지 않는다.

## 후보 1 — 비재귀 경로의 파이프라인 경계 재구성

**근거:** Ritchie Zhao, Mingxing Tan, Steve Dai, Zhiru Zhang, *Area-Efficient Pipelining for FPGA-Targeted High-Level Synthesis*, **DAC 2015**, DOI 10.1145/2744769.2744801. [저자 공개 원문](https://www.csl.cornell.edu/~zhiruz/pdfs/pipemap-dac2015.pdf).

논문은 LUT 매핑을 고려한 처리율 제약 파이프라인 스케줄링으로 LUT와 레지스터 비용을 함께 줄인다. 단순 연산별 지연 합 대신 실제 매핑 단위를 고려한다.

**우리 적용안:** 입력 투영·FEx·출력층 중 한 곳의 함수 경계와 내부 파이프라인 배치만 바꿔 중간 레지스터 및 제어·선택 회로의 비용을 비교한다. 입력 포트와 가중치 전달은 유지한다. GRU recurrent 곱셈의 zero-cycle 함수 경계는 II=2를 위해 기존에 분리했던 구조이므로 첫 후보에서는 건드리지 않는다. 이미 실패한 DATAFLOW 전체 제거도 반복하지 않는다.

이는 논문의 MILP 스케줄러를 Vitis에 탑재하는 직접 재현이 아니다. 논문의 매핑 인식 원리에 따라 소스 경계·directive를 통제한 자체 비교 실험이다. inline 또는 latency 설정 하나가 논문 전체 방법과 같다고 표현하지 않는다.

**사전 조사:** HLS 스케줄에서 중간값의 생성·소비 cycle과 파이프라인 정렬용 레지스터를 식별한다. 바꾸려는 경계가 실제로 비용을 만드는지 확인한 뒤 한 곳씩 수정한다. 단지 소스 변수 수가 줄었다는 이유로 회로가 작아졌다고 판단하지 않는다.

**판정:** 수치 연산·곱별 반올림·포화·누산 순서를 보존해 부모 및 독립 참조/C/RTL 전체 일치를 요구한다. HLS II=2, 15 ns 물리 timing, 호출 정체 여부, 실제 LUT·FF를 함께 비교한다. 레지스터 감소 대신 조합 경로가 길어지면 timing에서 탈락할 수 있다.

## 후보 2 — 내부 중간값 생존 구간과 레지스터 공유

**근거:** Philip Brisk et al., *Optimal Register Sharing for High-Level Synthesis of SSA Form Programs*, **IEEE TCAD 25(5), 2006**, DOI 10.1109/TCAD.2006.870409. [저자 기관 공개 원문](https://escholarship.org/content/qt6q06h45g/qt6q06h45g_noSplash_15b41a8eafdd6af4a14010daac6e8412.pdf).

논문은 생존 구간이 겹치지 않는 값을 같은 레지스터에 배치하는 문제를 SSA 간섭 그래프로 다룬다. 현재 HLS 스케줄에서 동시 생존하지 않는 내부 임시값을 찾아 함수/코드 범위를 재구성하는 적용 가능성을 조사한다.

단순 C 변수 재사용이나 블록 범위 축소로 Vitis가 반드시 물리 레지스터를 공유하는 것은 아니다. II=2 파이프라인에서는 서로 다른 샘플의 값이 동시에 살아 있을 수 있으므로 단일 샘플의 소스 순서만 보고 합치면 안 된다. 논문의 컴파일러 알고리즘을 구현하지 않고 소스만 바꾸는 경우 원리 기반 변형으로 기록한다.

**조사 대상:** 현재 Block_entry_split_proc는 LUT 4,593 / FF 9,201이다. 이 전체가 제거 가능한 중복 저장이라는 뜻은 아니다. 포트 프로토콜 유지에 필요한 저장과 내부 정렬·복사를 분리하고, 내부 값의 중복 저장만 검토한다. 세현의 bias 사전 합산·포화 제거를 재실행하는 후보와 구분한다.

**판정:** 외부 입력·reset 의미·연산을 유지하고, 먼저 FF 감소 여부를 확인한다. 공유에 따른 MUX가 늘어 LUT 또는 timing을 악화시킬 수 있다. 실제 개선이 없는 소스 정리는 채택하지 않는다.

## 검토했으나 현재 제외하는 방향

- **Multipumping:** Ronak·Fahmy, *Multipumping Flexible DSP Blocks for Resource Reduction on Xilinx FPGAs*, IEEE TCAD 2017. [저자 원문](https://sfahmy.github.io/publications/2017-tcad-ronak.pdf). DSP를 내부 고속 클록으로 공유하지만 추가 클록·선택·제어가 필요하다. 원문에서도 DSP 절감과 LUT 증가를 함께 보고하므로 현재 LUT/FF 감소 목표의 우선 후보로 선정하지 않는다.
- **상수 가중치 덧셈 그래프:** 현재 런타임 가중치 입력 전제를 유지할 수 없어 제외한다.
- **추가 FIFO 깊이 축소·동일 tanh band 압축:** 완료된 실패 실험을 그대로 반복하지 않는다.

## 공통 기준

부모는 채택된 v3.3이다. 전체 7,680샘플, 64샘플 호출, 2,560샘플 reset, 호출 오버헤드 제외 조건을 유지한다. II=2·15 ns setup/hold·배선 오류 0·공식 PA·독립 참조/C/RTL 검증이 필수다. 정확도 변경을 의도하지 않는 후보는 부모 출력과 bit-exact를 요구한다.

현재 1% 기준은 LUT 399개 또는 FF 413개다. 다른 자원 증가 1% 이하·BRAM 신규 사용 없음이라는 현재 선별 기준을 함께 적용한다. 신규 후보의 절감률은 미측정이며 논문의 절감률을 현재 설계의 예상치로 옮기지 않는다. 미달 후보는 실제 삭제하고 미채택 번호를 재사용한다.
