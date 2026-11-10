# v3.3까지 채택한 논문 기반 개선

기준은 sehyeon v2 final(a1998bd)에서 가져온 기존 v3다. 입력 I/Q·가중치 인터페이스와 II=2·실제 15 ns를 유지하고, 제공 7,680샘플의 독립 참조/C/RTL 및 PA를 검증했다.

| 버전 | 논문에서 참고한 원리 | 실제 적용 | 결과 |
|---|---|---|---|
| v3.1 | MP-DPD의 혼합 정밀도 | FEx inverse 16/6→16/5 | ACPR 개선으로 채택 |
| v3.2 | polynomial-plus-correction seed | 64항 보정 seed·정규화 NR 1회 | DSP 감소로 채택 |
| v3.3 | multipartite table-lookup-and-addition | sigmoid 부분 오프셋 표 합산 | LUT −931개(부모 대비 −2.28%)로 채택 |

## 논문과 적용 범위

- [MP-DPD, IEEE MWTL 2024](https://arxiv.org/abs/2404.15364): 혼합 정밀도 원리를 현재 FEx에 적용했다. 논문 모델의 QAT·학습을 재현한 것은 아니다.
- [Ercegovac·Muller·Tisserand, Simple Seed Architectures for Reciprocal and Square Root Reciprocal, Asilomar 2005](https://perso.ens-lyon.fr/jean-michel.muller/EMTAsilomar05.pdf): 선형식+보정 표 seed가 근거다. 현재 고정소수점 정규화·역정규화와 0 처리는 자체 설계다.
- [de Dinechin·Tisserand, Multipartite Table Methods, IEEE TC 54(3), 2005](https://perso.citi-lab.fr/fdedinec/recherche/publis/2005-TC-Multipartite.pdf): 부분 오프셋 표 분해가 근거다. 그룹별 최소 양자화 기울기와 현재 Q12 연산은 자체 적용이다.

논문의 절감률을 현재 FPGA의 예상 성능으로 옮기지 않는다. 최종 수치는 실제 배치배선과 PA 평가로 판정한다. 자원 감소와 정확도 변화, HLS 추정과 물리 구현 결과는 각각 구분한다.

## 최종 근거

- [v3.1 전체 결과](../results/v3.1/RESULTS.md)
- [v3.2 전체 결과](../results/v3.2/RESULTS.md)
- [v3.3 전체 결과](../results/v3.3/RESULTS.md)
- [누적 PPA](ppa_history_template.md)

현재 최종 채택은 v3.3, LUT 39,854 / FF 41,222 / DSP 355 / BRAM 0, II=2, 실제 주기 14.897 ns다. 이후 미완료 실험은 이 커밋의 결과 범위에 포함하지 않는다.
