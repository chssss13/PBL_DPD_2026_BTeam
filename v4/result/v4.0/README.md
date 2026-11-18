# v4.0 — FEx inverse 정밀도 변경

2026-11-15 버전 재정리: 기존 v3.4를 v4.0로 등록했다. 소스·설정·측정 결과는 그대로이며 새 합성을 수행한 것이 아니다. 보고서 내부의 원래 버전명과 실행 경로는 당시 근거로 유지한다.

2026-11-11 사용자 채택. 우리 v3.3에서 FEx `inverse_t`를 signed `16/6`에서 `16/5`로 변경한다. 전체 폭은 16비트로 유지하고 소수부를 10→11비트로 늘렸다. Taylor 초깃값과 Newton–Raphson 4회는 유지한다. [변경 diff](changes/inverse16_5.diff)

| 항목 | v3.3 | v4.0 |
|---|---:|---:|
| Python PA NMSE (dB) | -44.97 | -44.96 |
| Python PA ACPR 좌/우 (dBc) | -53.35 / -50.08 | -53.61 / -50.31 |
| HLS LOOP_T II / 추정 주기 | 2 / 13.840ns | 2 / 13.840ns |
| P&R LUT / FF / DSP / BRAM | 37,419 / 38,575 / 362 / 0 | 37,331 / 38,965 / 362 / 0 |
| P&R WNS / 비교 주기 | +0.089846ns / 14.910ns | +0.145132ns / 14.855ns |

PA는 동일 7,680샘플과 PA 모델로 Python 출력을 재평가했다. C-sim 전체 출력은 Python과 Q12 불일치 0. sigmoid 입력 코드 32,768개 검사도 통과했다. 2,560샘플마다 상태를 리셋했다. setup·hold 위반과 배선 오류는 0개다. 비교 주기는 `15-WNS`다. v4.0 RTL co-sim과 보드 실측은 수행하지 않았다.

## 재현

공백 없는 경로, Vitis HLS/Vivado 2024.1, Python 3.9 이상. 이 폴더에서 PowerShell로 실행한다.

```powershell
python scripts/verify.py --package
$env:TEAM_PYTHON = (Get-Command python).Source
$env:TEAM_RUN = 'replay01'
$env:TEAM_MODE = 'csynth' # C-sim만 실행하려면 csim
vitis_hls -f scripts/reproduce.tcl
vitis_hls -f scripts/implement.tcl
vivado -mode batch -source scripts/report_paths.tcl
```

새 실행 경로를 사용하므로 기존 결과는 보존된다. 동일한 15ns, uncertainty 1ns, LOOP_T II=2, DSP full reg false, Vivado `AreaOptimized_high` 설정이다. 기존 Python과 C-sim 출력에 대한 Q12 비교 후 합성한다. [C-sim 결과](reports/csim_comparison.json) · [PA 평가](reports/pa_comparison.txt) · [HLS](reports/ResGRU_csynth.rpt) · [타이밍](reports/timing_summary.rpt) · [자원](reports/utilization.rpt)

공유 패키지를 별도 재실행한 C-sim은 기존 Python·C-sim 참조 각각 7,680개 Q12 불일치 0이다. [재현 결과](reports/package_csim_comparison.json).
