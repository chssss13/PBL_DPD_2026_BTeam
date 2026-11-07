# v3.1 — sigmoid 보간 표 대칭 압축

사용자가 2026-11-06에 채택한 이전 v3 기준이다. 2026-11-07 이후에는 v3.2가 현재 채택본이다. 실험 식별자는 **C23**이며 부모는 [sehyeon v1 계열 v2 최종본](../../../v2/result/final/README.md)이다.

sigmoid의 256구간 선형 보간은 유지하면서 양수 쪽 표 128항을 저장하고 음수 쪽 구간 시작값을 대칭으로 복원한다. tanh와 나머지 연산은 유지한다. [소스와 csynth](../../package/results/final_sigmoid_symmetry_csynth/README.md), [기본 설정 P&R](../../package/results/final_sigmoid_symmetry_pnr_retry01/README.md), [채택 설정 P&R](../../package/results/c23_areaoptimized_high_synth/README.md).

| 항목 | v2 최종 | v3.1 기본 설정 | v3.1 채택 설정 N1b |
|---|---:|---:|---:|
| HLS LOOP_T II | 2 | 2 | 동일 RTL, 2 |
| P&R WNS / 비교 주기 | +0.093ns / 14.907ns | +0.149ns / 14.851ns | +0.060ns / 14.940ns |
| P&R LUT / FF | 41,387 / 41,088 | 40,734 / 41,071 | 39,862 / 41,168 |
| P&R DSP / BRAM | 362 / 0 | 362 / 0 | 362 / 0 |

C++ sigmoid 입력 32,768개 전수 비교와 제공 입력 7,680개 C-sim 출력은 기준과 Q12 기준 일치했다. PA NMSE −44.97dB 및 ACPR −53.35/−50.08dBc는 같은 입력의 기존 PA 평가와 출력 일치에 근거하며 v3.1에서 PA 모델을 새로 실행한 결과는 아니다. P&R은 IP 내부 15ns 조건에서 setup·hold 위반 0개다. RTL co-sim·외부 I/O 통합 타이밍·보드 실측은 미실시다.

2026-11-06 사용자 결정으로 Vivado 면적 중심 합성 [V01 / N1b](../../package/results/c23_areaoptimized_high_synth/README.md)의 `AreaOptimized_high`를 현재 v3.1 RTL의 구현 설정으로 채택한다. 기본 설정보다 LUT 872개가 감소해 3만 개대로 진입했지만, WNS 여유는 0.149→0.060ns로 줄었다. 이후 RTL이나 구현 조건을 바꾸어 타이밍이 맞지 않으면 이 옵션을 제외한 기본 설정으로도 합성·P&R을 다시 비교한다. 기존 v3.1 기본 설정 결과는 비교 기준으로 보존한다.

## 버전별 재현 패키지

`src/`와 `tb/`는 채택 C23 소스이며 v3.2의 P08 변경은 포함하지 않는다. `reports/`는 v3.1 채택 N1b 설정의 최종 배선 보고서와 C23 HLS 보고서다. [sigmoid 변경](changes/sigmoid_symmetry.diff), [Vivado 설정 변경](changes/areaoptimized_high.diff).

Python 3.9 이상, Vitis HLS/Vivado 2024.1 환경을 설정한 PowerShell에서 이 폴더를 작업 경로로 사용한다. 설치 경로가 아닌 패키지 상대경로를 사용하며, 기존 build 폴더는 덮어쓰지 않는다.

```powershell
python scripts/verify.py --package
$env:TEAM_PYTHON = (Get-Command python).Source
$env:TEAM_RUN = 'replay01'
$env:TEAM_MODE = 'csynth' # C-sim만 필요하면 csim
vitis_hls -f scripts/reproduce.tcl
vitis_hls -f scripts/implement.tcl
vivado -mode batch -source scripts/report_paths.tcl
```

입력 7,680개, 2,560개마다 상태 리셋. HLS 15ns / uncertainty 1ns / 목표 II2, 구현은 AreaOptimized_high / 15ns. 기존 Python·C-sim 참조와 Q12 비교 후 합성한다. 현재 최종본은 [v3.2](../v3.2/README.md)다.

2026-11-07 공유 패키지에서 별도 C-sim 재실행: Python 참조와 기존 C-sim 출력 각각 7,680개 Q12 불일치 0. [검증](reports/package_csim_comparison.json).
