# v5-1 · 3층 입력 기반 reset·update 게이트

GRU 3층의 reset·update 게이트에서 이전 은닉 상태에 대한 행렬곱 `W_hr × h_prev`, `W_hz × h_prev`를 제거했다. 두 게이트는 현재 층 입력과 bias로 계산한다. 후보 상태 계산과 최종 은닉 상태 갱신에는 이전 은닉 상태를 계속 사용한다.

Gang Li 외의 IGRNN 연구에서 이전 은닉 상태를 거치지 않고 현재 입력으로 게이트를 계산하는 아이디어를 가져왔다. 이 실험에서는 v4.6의 GRU 3층에 해당 변경을 적용했다. [Instant Gated Recurrent Neural Network Behavioral Model for Digital Predistortion of RF Power Amplifiers, IEEE Access, 2020](https://doi.org/10.1109/ACCESS.2020.2986816)

[v4.6 자체 재학습 체크포인트](../../README.md)에서 출발해 변경된 3층을 재학습했다. 데이터는 15/3, 가중치는 14/4 형식이다.

| C-sim·PA 정확도 | v4.6 자체 재학습 | v5-1 |
|---|---:|---:|
| NMSE (dB) | −45.39 | −44.28 |
| EVM (dB) | −49.32 | −47.63 |
| ACPR 좌 / 우 (dBc) | −53.46 / −50.25 | −52.09 / −49.21 |

| P&R 항목 | v4.6 | v5-1 기본 배선 | v5-1 배선 후 물리 최적화 |
|---|---:|---:|---:|
| 샘플 루프 II | 2 | 2 | 2 |
| LUT | 21,660 | 19,893 | 19,899 |
| FF | 19,171 | 18,125 | 18,125 |
| DSP | 347 | 307 | 307 |
| BRAM (36 Kib 타일) | 7.5 | 7.5 | 7.5 |
| WNS (ns) | +0.138 | −0.139 | +0.005 |
| setup 위반 종료점 | 0 | 61 | 0 |

배선 후 `phys_opt_design -directive AggressiveExplore`를 적용해 15 ns를 통과했다. v4.6 대비 LUT 1,761개, FF 1,046개, DSP 40개를 줄였고 정확도 기준을 모두 통과해 채택했다.
