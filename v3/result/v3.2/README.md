# v3.2 — recurrent 곱셈 결과 포화 제거

2026-11-07 사용자 채택. sehyeon v1 기반 v2 최종 → sigmoid 대칭표 v3.1 → **P08 / v3.2**. v3.1의 sigmoid 256구간 보간 표를 대칭으로 128항만 저장하는 방식과 Vivado `AreaOptimized_high` 설정을 유지한다.

`gru_cell.h`의 `Recurrent_Gate_MAC`(r/z)과 `Recurrent_N_Row_MAC`(n)에서 개별 recurrent 곱 결과를 signed 18/3으로 변환할 때 `AP_SAT`을 `AP_WRAP`으로 변경한다. 폭과 `AP_RND` 반올림, 입력 MAC 및 누산 이후 포화는 유지한다. [변경 diff](changes/p08.diff). 값이 표현 범위를 벗어나면 결과가 달라질 수 있다.

| 결과 | v3.1 | v3.2 |
|---|---:|---:|
| C-sim | 7,680개 Q12 일치 | 부모 출력과 7,680개 Q12 일치 |
| HLS II / 추정 주기 | 2 / 13.881ns | 2 / 13.881ns |
| HLS LUT / FF / DSP / BRAM18K | 212,845 / 127,980 / 489 / 0 | 192,560 / 127,980 / 489 / 0 |
| P&R LUT / FF / DSP / BRAM | 39,862 / 41,168 / 362 / 0 | 38,047 / 40,960 / 362 / 0 |
| P&R WNS / 비교 주기 | +0.060ns / 14.940ns | +0.155487ns / 14.845ns |

P&R은 xczu7ev-ffvc1156-2-e, Vivado 2024.1, 15ns IP 내부 조건, `AreaOptimized_high`; setup·hold 위반과 미배선 0이다. 비교 주기는 15−WNS이며 최악 데이터 경로 14.827ns와 구분한다. [타이밍](reports/timing_summary.rpt), [자원](reports/utilization.rpt), [100경로](reports/setup_paths100.rpt), [HLS](reports/ResGRU_csynth.rpt).

제공 입력 출력의 Q12 일치에 근거해 v2의 기존 PA 평가 NMSE −44.97dB, ACPR −53.35/−50.08dBc와 연결할 수 있다. v3.2에서 PA 모델을 새로 평가하거나 RTL co-sim, 보드 실측을 하지는 않았다. 테스트 벡터 일치는 모든 입력에 대한 동등성 증명이 아니다.

## 재현

Vitis HLS/Vivado 2024.1, Python 3.9 이상, 공백 없는 경로 필요. 이 폴더에는 소스, 테스트벤치, 가중치·입력, 기존 참조 출력, 재현 스크립트와 보고서가 있다. PowerShell에서 도구 환경을 설정한 후:

```powershell
python scripts/verify.py --package
$env:TEAM_PYTHON = (Get-Command python).Source
$env:TEAM_RUN = 'replay01'
$env:TEAM_MODE = 'csynth' # C-sim만 실행하려면 csim
vitis_hls -f scripts/reproduce.tcl
vitis_hls -f scripts/implement.tcl
vivado -mode batch -source scripts/report_paths.tcl
```

C-sim은 7,680 샘플, 2,560 샘플마다 상태 리셋 후 저장된 Python·기존 C-sim 출력과 비교한다. C-sim 전용 실행 뒤 csynth를 하려면 새 `TEAM_RUN`으로 실행한다. 기존 실행 폴더는 덮어쓰지 않는다. 합성·P&R은 각 실행에서 다시 판단한다.

공유 패키지에서 별도 C-sim 재실행: 기존 Python 참조와 C-sim 출력 각각 7,680개 Q12 불일치 0. [검증 결과](reports/package_csim_comparison.json).
