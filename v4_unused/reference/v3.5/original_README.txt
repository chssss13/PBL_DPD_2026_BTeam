# v3.5 — 출력층 21/6 누산

2026-11-12 사용자 채택. 부모는 v3.4. 출력층 W_out의 각 곱을 Q6.15로 반올림하고 21/6으로 누산한 뒤 bias를 더하여 최종 15/3으로 변환한다. inverse16/5, NR4, GRU·활성화·가중치는 유지한다. [변경 코드](changes/output_acc21.diff)

| 항목 | v3.4 | v3.5 |
|---|---:|---:|
| P&R LUT | 37331 | 37415 |
| P&R FF | 38965 | 38503 |
| DSP / BRAM | 362 / 0 | 362 / 0 |
| WNS(ns) | +0.145132 | +0.103748 |
| 비교주기(ns), 15-WNS | 14.854868 | 14.896252 |
| HLS II / 추정주기(ns) | 2 / 13.840 | 2 / 13.840 |
| HLS LUT / FF / DSP | 189092 / 121655 / 489 | 189404 / 121386 / 489 |
| HLS 호출 지연(cycles) | 149 | 150 |

| PA 지표 | float golden | v3.4 | v3.5 | v3.5−golden |
|---|---:|---:|---:|---:|
| NMSE(dB) | -45.52 | -44.96 | -45.03 | +0.49 |
| ACPR L(dBc) | -53.59 | -53.61 | -53.51 | +0.08 |
| ACPR R(dBc) | -50.43 | -50.31 | -50.38 | +0.05 |

차이는 반올림된 문서 수치 기준이며 양수는 golden보다 악화. PA는 Python 후보 출력 평가이며 C-sim 7680샘플 Q12 불일치 0으로 대응을 확인했다. reset2560. 부모 출력과 동일하다는 뜻이 아니다. setup/hold 위반0, WHS+0.036848ns, 미배선0, routing error0. RTL co-sim 및 보드 실측 미실시.

## 재현

Vitis HLS/Vivado2024.1, xczu7ev-ffvc1156-2-e, clock15ns, uncertainty1ns, DSP full reg false, 목표II2, Vivado AreaOptimized_high.

```powershell
python scripts/verify.py --package
$env:TEAM_PYTHON = (Get-Command python).Source
$env:TEAM_RUN = 'replay01'
$env:TEAM_MODE = 'csynth'
vitis_hls -f scripts/reproduce.tcl
vitis_hls -f scripts/implement.tcl
vivado -mode batch -source scripts/report_paths.tcl
```

새 실행 경로를 사용한다. 이 보관 패키지 자체의 별도 재합성은 하지 않았으며, 실행 후보의 소스·C-sim 출력·완료 보고서를 보존했다. Python PA 비교표에서 wide21_6.txt가 본 후보다. 원본 실행 위치: v3/package/results/v34_output_acc21_csynth.
