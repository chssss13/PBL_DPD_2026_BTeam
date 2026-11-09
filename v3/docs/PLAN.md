# 원래 v3에서 시작하는 개선 실험

현재 기준은 `src/`·`tb/` 등에 보존한 원래 v3이며 출처는 sehyeon v2 final, a1998bd입니다. sehyeon v3.3을 가져오거나 기준본의 HLS 재현 프로젝트를 추가하지 않습니다.

## 반드시 유지할 조건

- LOOP_T **II=2**.
- 구현 후 **15ns** 제약 통과: WNS/WHS≥0, setup/hold·배선 오류 0.
- PA NMSE≤−43.48dB, ACPR 좌/우≤−50.39/−47.83dBc.
- 독립 hw_ref와 C의 기능 비교 및 전체 후보 C/RTL 출력 일치.
- 7,680샘플, 64샘플 호출, 2,560샘플마다 reset. 처리율 판정에서 호출 오버헤드 제외.

정확도나 자원이 좋아도 II=2·15ns를 못 맞추면 채택하지 않습니다. 목표를 더 짧은 클럭으로 무리하게 잡지 않습니다.

## 진행 순서

1. 관련 논문의 기법을 현재 구조에 맞게 한 가지씩 적용합니다.
2. v3.1부터 후보별 소스·조건·변경 diff를 고정합니다. 기존 기준 소스는 덮어쓰지 않습니다.
3. Python 정수 참조·C·PA부터 확인합니다. 정확도 개선이 작고 자원 감소도 기대되지 않으면 이 단계에서 종료합니다.
4. 자원 개선 후보는 HLS 추정만으로 성패를 확정하지 않습니다. II=2 → 전체 RTL → 구현 순서로 실제 결과를 확인합니다.
5. 필수 조건을 통과한 후보에서 실질적 이득을 평가합니다. 첫 자원 후보의 선별 기준은 LUT/FF/DSP 중 하나가 1% 이상 감소하고 다른 자원이 1% 넘게 증가하지 않는 것입니다. 이는 공식 요구 조건과 별도의 실험 선별 기준입니다.
6. 개선이 없거나 작으면 해당 후보의 소스·결과·상세 문서를 **실제로 삭제**합니다. 별도 보관본을 만드는 것으로 대신하지 않습니다. 도구 오류는 설계 실패와 구분하며 삭제가 도구 정책에 차단되면 그 사실을 보고합니다.

## 첫 후보와 후속 검토

이전 대칭 표 후보는 자원 개선이 1% 미만이어서 소스·결과·문서를 실제 삭제했습니다. 보관본으로 대체하지 않았습니다.

**새 v3.1: FEx inverse 혼합 정밀도.** 기존 16/6에서 16/5로 정수부·소수부를 재배분합니다. 총 비트폭과 NR 4회 반복은 유지하며 독립 참조·PA·II=2·RTL·15ns를 검증합니다.

현재 v3.1은 II=2·14.750ns 및 C/RTL·PA 검증을 완료해 유지 조건을 만족했습니다. 단순 정밀도 탐색이었던 후속 16/4·17/6 예약은 해제했습니다. 이후 방향은 원문 검토에서 선정한 [논문 기반 후보 A→B→C](PAPER_CANDIDATES.md)를 따릅니다.
자원 사용량 감소를 우선하라는 사용자 요청에 따라 [v3.2 보정 seed·NR 4→1](v3.2_corrected_seed.md)을 시작했습니다. 부모 v3.1은 보존합니다. 이번 후보는 정확도 개선만으로 채택하지 않고 실제 구현 자원 감소를 요구합니다. PA의 부모 대비 변화도 보고하며 공식 정확도 조건은 유지합니다.
기준 미달이면 후보 파일을 실제 삭제하고 채택 전의 버전 번호를 재사용합니다. 폐기한 변경을 다음 후보에 누적하지 않습니다.

## 논문 근거

- **An Instruction-Driven Batch-Based High-Performance Resource-Efficient LSTM Accelerator on FPGA**, Electronics 12(7), 1731, 2023. sigmoid/tanh의 내부 대칭성을 이용해 표의 절반만 저장하는 원리를 참고합니다. LSTM 가속기 전체를 재현하거나 해당 논문의 성능 수치를 현재 GRU에 적용하지 않습니다. [원문](https://www.mdpi.com/2079-9292/12/7/1731).
- **Activation Function Architectures for FPGAs**, FPL 2018. RNN 재귀 경로에서 활성화 함수의 지연·자원 비용과 입력 범위 분해를 검토한 자료입니다. 현재 activation의 zero-cycle 제약을 유지하는 설계 판단에 참고합니다. [저자 공개 원문](https://bogdan-pasca.org/resources/publications/2018-FPL-Activations.pdf).
- **MP-DPD: Low-Complexity Mixed-Precision Neural Networks for Energy-Efficient Digital Predistortion of Wideband Power Amplifiers**, MWTL 2024. DPD 혼합 정밀도 설계의 후속 검토 자료입니다. 이번 v3.1에서는 비트폭이나 가중치를 바꾸지 않습니다. [원문](https://arxiv.org/abs/2404.15364).

## 실행과 결과

`C:/Project/venv_dpd/Scripts/python.exe v3/scripts/run_flow.py v3.1`

[진행표](../results/batch/SUMMARY.md) · [v3.1 상세](v3.1_fex_mixed_precision.md)

무거운 작업은 후보 하나씩 순차 실행합니다. 원본의 실제 자원과 타이밍은 가져온 측정값이고 후보는 이 PC의 측정값이므로, 물리 구현 환경 차이가 결과에 포함될 수 있습니다.
