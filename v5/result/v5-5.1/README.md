# v5-5.1 · DSP 8개를 LUT로 전환

v5-5의 DSP 228개 중 8개를 LUT로 옮겼다. ZU7EV 배치·배선 후 **DSP 220개, WNS +0.132 ns**로 목표 주기 15 ns를 충족했다. 기존 v5-5의 59 epoch float 재학습 가중치를 사용했다. [부모 구현과 가중치](../v5-5/README.md)

## 변경 내용

- PReLU 곱셈 5개에 `use_dsp = "no"`를 지정했다. 기존처럼 실행 중에 전달되는 PReLU 계수를 사용한다.
- FEx에서는 `Q²` 제곱기 1개와 역제곱근 값을 I·Q에 곱하는 연산 2개를 LUT로 옮겼다.
- 생성 RTL에서 해당 곱셈기의 매핑 속성만 바꾸고, 기존 샘플 루프 II=2 스케줄과 고정소수점 연산을 계승했다. [RTL](rtl)

## 배치·배선과 정확도

Vivado 2024.1, `xczu7ev-ffvc1156-2-e`, 목표 15 ns, 합성 지시어 `AreaOptimized_high`를 사용했다.

| 항목 | v5-5 | v5-5.1 | 변화 |
|---|---:|---:|---:|
| LUT | 15,527 | 17,349 | +1,822 (+11.7%) |
| FF | 12,660 | 12,690 | +30 (+0.2%) |
| DSP | 228 | 220 | −8 (−3.5%) |
| BRAM (36 Kib 타일) | 7.5 | 7.5 | 0 |
| WNS (ns) | +0.515 | +0.132 | −0.383 |
| 샘플 루프 II | 2 | 2 | 0 |

Icarus Verilog로 120회 호출의 I/Q 7,680쌍을 비교했다. 15,360개 출력 워드가 부모 C-sim 출력과 비트 단위로 일치했다. 이 평가 벡터의 NMSE는 −43.89 dB, EVM은 −47.41 dB, 좌·우 ACPR은 −50.91 / −48.91 dBc다. `python verify.py`로 검증을 재현할 수 있다. [검증 결과](reports/verification.txt) · [검증 벡터](test)

[자원 보고서](reports/utilization.rpt) · [계층별 자원](reports/utilization_hierarchical.rpt) · [타이밍 보고서](reports/timing_summary.rpt) · [배선 상태](reports/route_status.rpt)
