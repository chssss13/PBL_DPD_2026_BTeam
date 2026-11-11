# v3.3 — r/z bias 사전 합산

2026-11-07 사용자 채택. [v3.2](../v3.2/README.md)에서 GRU의 r·z 게이트 bias 쌍을 샘플 처리 전에 호출당 한 번 합산한다. signed `16,4` 형식으로 기존 두 Q12 bias의 합을 정확히 저장하고, gate 입력의 최종 변환을 유지한다. n bias는 r 곱 안팎에 있어 합산하지 않는다. 외부 입력 인터페이스와 DATAFLOW는 유지한다. [소스 변경](changes/rz_bias_presum.diff).

| 결과 | v3.2 | v3.3 |
|---|---:|---:|
| C-sim | 7,680개 Q12 일치 | 부모 참조 7,680개 Q12 일치 |
| HLS II / 추정 주기 | 2 / 13.881 ns | 2 / 13.840 ns |
| HLS LUT / FF / DSP / BRAM18K | 192,560 / 127,980 / 489 / 0 | 189,110 / 121,655 / 489 / 0 |
| P&R LUT / FF / DSP / BRAM | 38,047 / 40,960 / 362 / 0 | **37,419 / 38,575 / 362 / 0** |
| P&R WNS / 비교 주기 | +0.155487 / 14.845 ns | +0.089846 / 14.910 ns |

v3.2 대비 P&R LUT −628개(−1.65%), FF −2,385개(−5.82%), DSP·BRAM 동일. WNS 여유는 약 0.066 ns 감소했다. 15 ns IP 내부 제약에서 setup·hold 위반 및 배선 오류는 0개다. 비교 주기는 15−WNS이며 최악 데이터 경로 지연 14.793 ns와 구분한다. 외부 I/O 지연 제약은 별도다. [타이밍](reports/timing_summary.rpt) · [자원](reports/utilization.rpt) · [최악 100경로](reports/setup_paths100.rpt) · [HLS](reports/ResGRU_csynth.rpt).

C-sim은 제공된 7,680개 벡터의 Q12 출력 일치다. 이 결과를 근거로 이전 PA 평가 NMSE −44.97 dB, ACPR −53.35/−50.08 dBc를 해당 벡터의 참조값으로 연결할 수 있다. v3.3에서 PA 모델을 새로 평가하거나 RTL co-sim·보드 실측을 수행하지 않았다. 테스트 벡터의 일치와 모든 입력·가중치에 대한 동등성 증명은 다르다.

## 재현

Vitis HLS/Vivado 2024.1, Python 3.9 이상, 공백 없는 경로 필요. 소스, 테스트벤치, 입력·가중치, 참조 출력, 스크립트 및 보고서를 포함한다. PowerShell에서 도구 환경을 설정한 후:

```powershell
python scripts/verify.py --package
$env:TEAM_PYTHON = (Get-Command python).Source
$env:TEAM_RUN = 'replay01'
$env:TEAM_MODE = 'csynth' # C-sim만 실행하려면 csim
vitis_hls -f scripts/reproduce.tcl
vitis_hls -f scripts/implement.tcl
vivado -mode batch -source scripts/report_paths.tcl
```

7,680샘플, 2,560샘플마다 상태 리셋하고 저장된 Python·기존 C-sim 출력과 비교한다. C-sim 전용 실행 뒤 csynth를 하려면 새 `TEAM_RUN`을 쓴다. 재현 실행은 기존 결과를 덮어쓰지 않는다. HLS·P&R의 자원과 타이밍은 재실행마다 확인한다.

공유 패키지 C-sim 재실행: 기존 Python 참조와 C-sim 출력 각각 7,680개 Q12 불일치 0. [검증 결과](reports/package_csim_comparison.json).
