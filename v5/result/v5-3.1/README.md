# v5-3.1 · 전 층 bias-only 게이트

1·2·3층의 reset·update 게이트를 학습한 bias로 계산한다. 후보 상태는 현재 입력과 이전 상태를 계속 사용한다. 기존 v5-3은 3층만 변경한 실험이다. 이 버전은 샘플 루프 II=2, v4.6의 RTL 최적화와 지연 레지스터의 SRL 매핑을 적용했다.

v4.6 자체 재학습 가중치에서 시작해 Adam, 학습률 0.00025로 50 epoch를 실행했다. 그중 49번째 가중치에서 20 epoch를 추가 학습했다. 제공 벡터에서 최종 NMSE −32.26 dB, EVM −34.19 dB, ACPR 좌/우 −37.27 / −34.83 dBc로 정확도 기준 미달이다. [첫 학습](reports/first50.csv) · [추가 학습](reports/continue20.csv)

Vivado 2024.1, xczu7ev-ffvc1156-2-e, 15 ns, AreaOptimized_high. 배선 후 LUT 13,469개, FF 9,071개, DSP 187개, BRAM 7.5타일이며 WNS +1.569 ns로 타이밍을 통과했다. [자원](reports/ResGRU_utilization_routed.rpt) · [타이밍](reports/ResGRU_timing_routed.rpt)

[src](src)는 HLS 소스, [rtl](rtl)은 배선에 사용한 최종 Verilog와 ROM 초기값이다. [weights](weights)는 두 버전이 공유하는 최종 가중치와 bias이며 [test](test)에 고정 가중치 테스트벤치, 입력과 C-sim 기준 출력이 있다. [v5-3.2](../v5-3.2/README.md)는 같은 모델에서 2층 전달 경로를 변경했다.
