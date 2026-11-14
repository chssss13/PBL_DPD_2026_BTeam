# v3 적용 논문과 기법 정리

최종 정리: 2026-11-15. 현재 남아 있는 v3.1~v3.7의 변경과 실제 근거를 정리한다. 파일명은 기존 링크를 위해 유지하지만 미실행 후보나 종료된 실험의 예약표가 아니다. 수치는 저장된 실제 구현 결과이며 논문의 절감률을 옮긴 값이 아니다.

## 버전별 적용 관계

각 버전은 바로 앞 채택본을 부모로 한다. v3 기준 원본은 sehyeon v2 최종본을 도입한 설계이며, 아래는 그 이후 추가한 변경이다.

| 버전 | 추가한 변경 | 논문·출처 | 적용 수준 |
|---|---|---|---|
| [v3.1](v3.1_fex_mixed_precision.md) | FEx inverse 16/6(Q10) → 16/5(Q11) | MP-DPD, IEEE MWTL 2024 | 정밀도 배분 방향 참고. 혼합 정밀도 학습·QAT 재현은 아님 |
| [v3.2](v3.2_corrected_seed.md) | 정규화 + 보정 seed + NR 4회 → 1회 | Simple Seed Architectures for Reciprocal and Square Root Reciprocal, Asilomar 2005 | polynomial-plus-correction seed를 참고한 고정소수점 적용 |
| [v3.3](v3.3_multipartite.md) | sigmoid 보간 곱셈 → multipartite 표·덧셈 | Multipartite Table Methods, IEEE TC 2005 | 부분 오프셋 분해 원리 적용 + 단조성 보존을 위한 자체 변형 |
| [v3.4](v3.4_sehyeon_incremental.md) | Vivado AreaOptimized_high | sehyeon 176b59b의 합성 설정 | 도구 설정 도입. 별도 논문 기법이 아님 |
| [v3.5](v3.5_sehyeon_incremental.md) | recurrent 개별 곱 변환 AP_SAT → AP_WRAP | sehyeon 176b59b의 코드 | 팀원 기법 도입. 별도 논문 기법이 아님 |
| [v3.6](v3.6_fifo_share.md) | FIFO 598개의 제어를 32개씩, 총 19개로 공유 | Removing Overhead from High-Level Interfaces, DAC 2012 | 중복 인터페이스 제거 원리를 참고한 자체 RTL 변형. 논문의 SAT 분석기 재현은 아님 |

MWTL·Asilomar·IEEE TC는 이후 사용자가 우선순위로 지정한 ISCAS·TCAS·TCAD·TVLSI·DAC와 구분한다. 기존 적용 이력을 다른 venue의 논문을 적용한 것처럼 바꾸지 않는다.

## v3.1 — MP-DPD: 정밀도 배분 방향 참고

**Yizhuo Wu et al., “MP-DPD: Low-Complexity Mixed-Precision Neural Networks for Energy-Efficient Digital Predistortion of Wideband Power Amplifiers,” IEEE Microwave and Wireless Technology Letters, 2024.**

- [저자 공개 논문·서지](https://arxiv.org/abs/2404.15364)
- DOI: [10.1109/LMWT.2024.3386330](https://doi.org/10.1109/LMWT.2024.3386330)

**논문 내용:** DPD 신경망에 저정밀 고정소수점 파라미터와 혼합 정밀도를 적용해 계산·저장 비용을 줄인다.

**우리 적용:** FEx inverse의 총 16비트는 유지하고 정수부를 6→5, 소수부를 10→11비트로 재배분했다. 범위와 해상도의 교환 관계를 검증했다. NR 초기식과 반복 4회, GRU 자료형 및 활성화는 이 단계에서 유지했다.

**적용 범위:** 논문의 혼합 정밀도 학습이나 QAT를 수행하지 않았다. 논문이 FEx inverse 16/5 형식을 제시하거나 최적성을 보장하는 것도 아니다. 논문 알고리즘 직접 재현보다 정밀도 설계 방향을 참고한 실험이다.

**관측 결과:** 원본 대비 PA NMSE는 +0.0082 dB, ACPR 좌/우는 -0.2625/-0.2257 dB 변화했다. 모든 지표가 좋아진 것은 아니며 공식 PA 기준을 만족하면서 ACPR 개선을 확인했다. [상세 및 측정 근거](v3.1_fex_mixed_precision.md)

## v3.2 — 보정 seed로 NR 반복 축소

**Milos Ercegovac, Jean-Michel Muller, Arnaud Tisserand, “Simple Seed Architectures for Reciprocal and Square Root Reciprocal,” 39th Asilomar Conference on Signals, Systems and Computers, 2005.**

- [저자 공개 원문](https://perso.ens-lyon.fr/jean-michel.muller/EMTAsilomar05.pdf)
- [저자 논문 목록의 서지](https://perso.ens-lyon.fr/jean-michel.muller/publications.html)

**논문 내용:** 간단한 다항식과 보정 표를 조합해 reciprocal 및 reciprocal square root 반복 연산의 초기값을 만든다. 적용 근거는 III절의 polynomial-plus-correction seed다.

**우리 적용:** amp2를 최상위 비트 기준으로 [1,2)로 정규화한다. 5/4−m/4와 64항 보정 표로 초기값을 만들고 y=y·(1.5−0.5·m·y²)를 1회 수행한다. 홀수 지수 보정 및 역정규화 후 inverse 16/5로 변환한다.

**자체 설계:** 보정 계수, 중간 비트폭, 반올림·포화, 홀수 지수 상수 46341(Q16), amp2=0 처리는 현재 FEx에 맞췄다. 보정 표는 정규화 영역의 함수 오차를 대상으로 구성했으며 제공 I/Q 데이터로 학습하지 않았다.

**관측 결과:** 부모 대비 DSP 362→355(-1.93%), LUT -394개. amp2 입력 코드 16,384개 전수 비교와 전체 네트워크 검증을 수행했다. [상세 및 측정 근거](v3.2_corrected_seed.md)

## v3.3 — Multipartite Table Methods

**Florent de Dinechin, Arnaud Tisserand, “Multipartite Table Methods,” IEEE Transactions on Computers, vol. 54, no. 3, pp. 319–330, March 2005.**

- [저자 공개 원문](https://perso.citi-lab.fr/fdedinec/recherche/publis/2005-TC-Multipartite.pdf)
- DOI: [10.1109/TC.2005.54](https://doi.org/10.1109/TC.2005.54)

**논문 내용:** 함수 평가를 기준값 표와 여러 부분 오프셋 표의 덧셈으로 구성하고 입력 주소 분해와 근사 오차를 고려해 표 크기와 계산 비용을 조절한다.

**우리 적용:** sigmoid의 base+delta×fraction을 기준 표와 세 부분 오프셋 표의 합으로 대체했다. 15비트 위치 코드를 상위 8비트 구간 주소와 하위 [3,2,2]비트로 나누고, 부분 표의 기울기 주소 정밀도는 [2,5,5], guard는 3비트다.

**자체 설계:** 그룹별 최소 양자화 기울기로 구간 경계의 단조성을 보존한다. 논문의 회로 전체를 복제한 것은 아니다. sigmoid에만 적용했으며 현재 채택된 tanh는 기존 256구간 보간이다.

**관측 결과:** 부모 대비 LUT 40,785→39,854(-2.28%). 함수 입력 코드 32,768개 전수 검사와 전체 네트워크 검증을 수행했다. [상세 및 측정 근거](v3.3_multipartite.md)

## v3.4·v3.5 — 논문과 구분하는 팀원 기법 도입

출처는 [sehyeon commit 176b59b](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/176b59b/v3/result/v3.3)다. 우리 v3.3 위에 변경을 하나씩 도입했으며 세현 최종본 전체로 기준을 교체한 것은 아니다.

| 버전 | 실제 변경 | 부모 대비 결과 | 해석 |
|---|---|---|---|
| v3.4 | Vivado synth_design directive를 AreaOptimized_high로 변경 | LUT -905개, FF -171개 | 도구 설정 비교이며 새 논문 알고리즘이 아님 |
| v3.5 | recurrent 개별 곱의 18/3 변환을 AP_SAT→AP_WRAP으로 변경 | LUT -1,638개, FF +257개 | 입력 MAC이나 전체 누산 포화를 모두 제거한 것이 아님 |

v3.5는 검증 벡터에서 부모와 출력이 같았다. 범위를 넘는 입력에서도 SAT와 WRAP이 항상 동등하다는 주장은 하지 않는다. [v3.4 상세](v3.4_sehyeon_incremental.md) · [v3.5 상세](v3.5_sehyeon_incremental.md)

## v3.6 — 인터페이스 중복 제어 제거

**Kyle Kelley, Megan Wachs, John P. Stevenson, Stephen Richardson, Mark Horowitz, “Removing Overhead from High-Level Interfaces,” DAC 2012, pp. 783–789.**

- DOI: [10.1145/2228360.2228502](https://doi.org/10.1145/2228360.2228502)
- [저자 학위논문 Chapter 3](https://www-vlsi.stanford.edu/people/alum/pdf/1208_Kelly_HighLevelDigitalInterfaces.pdf): 기술 내용을 확인한 자료이며 DAC 논문 PDF와 구분한다.

**논문 내용:** 순차 도달가능 상태 분석으로 일반적인 고수준 인터페이스에서 실제로 필요 없는 상태·제어·버퍼 비용을 찾아 제거한다.

**우리 적용:** v3.5 진입부와 샘플 연산부 사이 FIFO 598개의 초기 상태, reset, read, 생산자 완료 및 write 동기화 전이식이 같은 구조인지 검사한다. 같은 상태로 움직이는 제어부를 최대 32개씩 묶어 19개 제어부로 공유한다. 데이터 저장부 598개와 깊이 2, 채널별 비트폭 및 병렬 전달은 유지한다.

**자체 설계:** 논문의 SAT 분석기는 구현하지 않았다. 구조 조건 검사와 동일 상태를 유지한다는 귀납 관계에 근거한 RTL 후처리다. C++만 합성해서는 이 회로가 나오지 않으며 변경 RTL의 co-simulation과 IP export 후 동일 RTL 설치가 필요하다.

**관측 결과:** 부모 대비 LUT -4,869개(-13.05%), FF -3,908개(-9.46%), DSP·BRAM 동일. 실제 14.973 ns, II=2, WHS +0.037 ns, 배선 오류 0. 제공된 7,680샘플에서 변경 RTL과 C 출력이 같고 PA 지표도 유지됐다.

**남은 검증:** 가중치 변경, 다양한 reset·호출 간격·backpressure 조합의 추가 회귀 검증과 전체 회로의 formal 동등성 검증은 수행하지 않았다. 정확도 유지 주장은 현재 검증 입력·가중치 범위에 해당한다. [상세 및 측정 근거](v3.6_fifo_share.md)

## 실제 구현 결과 요약

### v3.7 — FIFOAdvisor 방향을 참고한 저장 깊이 축소

[FIFOAdvisor: A DSE Framework for Automated FIFO Sizing of High-Level Synthesis Designs](https://arxiv.org/html/2510.20981v1), ASP-DAC 2026의 시뮬레이션 기반 용량 탐색을 참고했다. 논문의 탐색기나 BRAM 목적 함수를 재현한 것이 아니라, v3.6의 32개 단위 제어 공유를 유지하면서 payload 깊이를 2→1로 바꾼 자체 후보다. ASP-DAC은 DAC 본 학회와 구분한다.

실제 LUT 27,127개, FF 28,978개, DSP 355개, BRAM 0개, II=2, 주기 14.907 ns다. 부모 대비 LUT -5,315개(-16.38%), FF -8,422개(-22.52%). 20,000클럭 FIFO 단위 검증과 전체 7,680샘플 수정 RTL 출력 일치, 호출 간격 134클럭·전체 실행 16,091클럭 유지를 확인했다. 임의의 호출 중첩에서 매 클럭 동등하다는 뜻은 아니며 추가 가중치/reset 검증은 남아 있다. [상세](v3.7_fifo_depth.md)

모든 행의 LOOP_T II는 2이며 구현 클록 제약은 15 ns다. 감소는 -, 증가는 +로 표시한다. 변화량은 바로 앞 채택본 대비이며 논문 결과가 아니다.

| 버전 | LUT | FF | DSP | BRAM_18K | Post-Route 주기(ns) | 부모 대비 LUT / FF |
|---|---:|---:|---:|---:|---:|---|
| v3 기준 원본 | 41,387 | 41,088 | 362 | 0 | 14.907 | — |
| v3.1 | 41,179 | 41,132 | 362 | 0 | 14.750 | -208 / +44 |
| v3.2 | 40,785 | 41,227 | 355 | 0 | 14.952 | -394 / +95 |
| v3.3 | 39,854 | 41,222 | 355 | 0 | 14.897 | -931 / -5 |
| v3.4 | 38,949 | 41,051 | 355 | 0 | 14.968 | -905 / -171 |
| v3.5 | 37,311 | 41,308 | 355 | 0 | 14.893 | -1,638 / +257 |
| **v3.6** | **32,442** | **37,400** | **355** | **0** | **14.973** | **-4,869 / -3,908** |
| **v3.7** | **27,127** | **28,978** | **355** | **0** | **14.907** | **-5,315 / -8,422** |

원본부터 v3.6까지 누적 변화는 LUT -8,945개(-21.61%), FF -3,688개(-8.98%), DSP -7개(-1.93%)다. 누적 감소를 어느 한 논문의 효과로 전부 귀속하지 않는다. [누적 PPA 이력](ppa_history_template.md)

## 적용하지 않은 문헌의 취급

TARO, mapping-aware buffer placement, register sharing 등은 조사했지만 현재 남아 있는 버전에 해당 알고리즘을 구현하지 않았다. FIFOAdvisor는 v3.7의 방향 참고이며 탐색 알고리즘 직접 적용으로 분류하지 않는다. 삭제된 실험의 과거 실행 문구와 예약 계획도 이 문서에서 제거했다.

최종 수치와 검증 범위는 각 버전의 상세 문서 및 results/v3.n/RESULTS.md를 따른다. v3.7은 저장된 검증 기준을 통과했으며 현재 실행 중이거나 예약된 작업은 없다. 진입부의 중복 저장 제거는 아직 적용하지 않았다.
