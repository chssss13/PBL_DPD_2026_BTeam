# LW-ResGRU 최종 구현

2026-11-04. 이 폴더만 복사하면 변경 이력을 읽고 최종 C++의 C-sim·HLS 합성·Vivado 배치·배선을 실행할 수 있다. 기준 구현은 `v1_gru_accum_wide_z_unsigned12_state_nosat_csynth`이며, 기존 v2.4-S 이후 채택한 변경15번까지 포함한다.

## v2.4-S 이후 채택한 변경

기존 v2.4-S에서 다음 다섯 변경을 누적했다. 번호는 상세 변경 이력의 11~15번과 같다.

1. GRU 행렬곱을 21,6 형식으로 누산한 뒤 최종 18,3으로 변환.
2. recurrent 곱셈 함수를 게이트·입력 항별로 분리.
3. n recurrent 곱셈을 출력 행별로 추가 분리.
4. 상태 갱신의 z를 unsigned12,0으로 표현하면서 소수부 12비트 유지.
5. 상태 갱신 결과의 범위를 확인하고 최종 포화 처리를 생략. 반올림은 유지.

| P&R 항목 | v2.4-S | 현재 최종 | 차이 |
|---|---:|---:|---:|
| WNS (ns) | -2.524 | +0.093 | +2.617 |
| 비교 주기 (ns, 15−WNS) | 17.524 | 14.907 | -2.617 |
| LUT | 47,575 | 41,387 | -6,188 |
| FF | 41,799 | 41,088 | -711 |
| DSP | 333 | 362 | +29 |
| BRAM | 0 | 0 | 0 |

두 구현 모두 HLS II=2다. [전체 변경 요약](docs/v1_v2_변경요약.md)에서 헤더·함수별 설명과 diff로 이동할 수 있다. 최종 코드는 `src/`에 있으며, 저장소의 `v2/package/src/`는 기존 v2.3 계보의 코드다.

## 읽는 순서

1. [v1 / v2 변경 요약](docs/v1_v2_변경요약.md): 변경 목록과 버전 구분.
2. [코드 변경 부분](changes/코드변경.md): 어떤 헤더·함수에서 무엇이 바뀌었는지, 이전 단계와의 차이. 각 요약 항목에서 바로 이동할 수 있다.
3. [채택 변경 이력](docs/v1기반_채택변경_이력.md): 당시 문제 인식과 선택 과정.
4. [논문 아키텍처 대응](docs/v1기반_변경과_논문아키텍처_대응.md): 논문의 블록·수식에 해당하는 위치와 근거.

## 포함된 파일

| 폴더·파일 | 내용 |
|---|---|
| `docs/` | 위 문서3개를 공유용 상대경로로 정리 |
| `changes/` | 변경 부분 모음과10~15번의 실제 diff |
| `src/`, `tb/` | 최종 합성에 사용한 소스·테스트벤치14개 원본 |
| `golden/` | 테스트벤치가 읽는 학습 가중치와7,680개 I/Q 입력 |
| `reference/` | 기존 Python 참조 출력과 최종 C-sim 출력 |
| `scripts/` | 새 실행용 C-sim·csynth·P&R·100경로 추출 및 출력 검증 |
| `reports/` | 기존 최종 HLS·P&R 보고서, 범위 검사와 C-sim 비교 결과 |
| `source_sha256.json` | 기존 최종 소스·테스트벤치의 식별 해시 |
| `SHA256SUMS.json` | 이 재현 보관본 파일의 무결성 확인용 해시 |

과거 실험 전체 프로젝트와 중간 산출물은 필요하지 않다. 문서의 과거 단계는 변경 설명·diff로 읽고, 실행에는 최종 `src/`를 사용한다. `reports/`의 절대경로는 원래 실행 당시 보고서에 남은 표기이며, 새 실행 스크립트는 해당 경로를 사용하지 않는다.

## 실행 환경

- Vitis HLS 2024.1, Vivado 2024.1 및 대상 디바이스 지원 설치.
- Python 3.9 이상. 제공 검증 스크립트는 표준 라이브러리만 사용한다.
- 폴더는 `C:/PBL/PBL_DPD_2026_BTeam/v2/result/final`처럼 공백 없는 영문 경로에 둔다. Vitis HLS 2024.1은 공백이 있는 프로젝트 경로를 거부한다.
- 디바이스 `xczu7ev-ffvc1156-2-e`, 클록15ns, HLS uncertainty1ns, DSP full reg false, LOOP_T II=2 요청.
- H=5, L=3, 입력7,680개, 상태 리셋2,560개마다. data15,3·weight14,4, sigmoid/tanh256구간.

아래 명령은 이 폴더에서 PowerShell로 실행한다. 먼저 사용하는 PC의 설치 경로에 맞춰 Vitis HLS/Vivado 실행 환경을 설정하여 `vitis_hls`, `vivado` 명령을 사용할 수 있게 한다. 설치 프로그램이 제공하는 command prompt 또는 `settings64.bat`를 적용한 환경을 사용하면 된다.

```powershell
python scripts/verify.py --package
# PATH의 python 대신 특정 Python을 쓸 때만 지정
$env:TEAM_PYTHON = (Get-Command python).Source
```

## 1. C-sim과 csynth 재현

```powershell
$env:TEAM_RUN = 'replay01'
$env:TEAM_MODE = 'csynth'
vitis_hls -f scripts/reproduce.tcl
```

진행 순서는 **파일 확인 → C-sim → 두 참조 출력과 Q12 비교 → csynth**다. 출력이 다르면 합성으로 넘어가지 않고 오류로 종료한다. 실행 결과는 `build/replay01/`에 생성되며, 기존 실행 폴더가 있으면 덮어쓰지 않는다. 다시 실행하려면 `TEAM_RUN`을 `replay02`처럼 새 이름으로 바꾼다.

C-sim만 먼저 확인하려면 별도 이름을 사용한다.

```powershell
$env:TEAM_RUN = 'csim_only'
$env:TEAM_MODE = 'csim'
vitis_hls -f scripts/reproduce.tcl
```

C-sim 전용 실행 후 합성도 하려면 새 `TEAM_RUN`에서 `csynth` 모드로 실행한다. 다음 파일에서 결과를 확인한다.

- `build/<TEAM_RUN>/csim_comparison.json`: Python·기존 C-sim 각각 Q12 불일치0인지 확인.
- `build/<TEAM_RUN>/prj/sol1/syn/report/Loop_LOOP_T_proc_csynth.rpt`: LOOP_T II.
- `build/<TEAM_RUN>/prj/sol1/syn/report/ResGRU_csynth.rpt`: HLS 추정 타이밍·자원.

## 2. 같은 합성 결과로 P&R 진행

```powershell
$env:TEAM_RUN = 'replay01'  # csynth가 완료된 실행 이름
vitis_hls -f scripts/implement.tcl
```

구현 결과가 이미 있으면 덮어쓰지 않는다. P&R을 다시 시도하려면 새로운 실행 이름에서 합성부터 진행한다. 구현 완료 후 Vivado로100경로와 요약 보고서를 추출한다.

```powershell
$env:TEAM_RUN = 'replay01'
vivado -mode batch -source scripts/report_paths.tcl
```

새 보고서는 `build/replay01/timing100/`에 생긴다. 실제 타이밍 통과 여부는 `timing_summary.rpt`의 WNS·TNS와 setup/hold 위반으로 판단한다.

## 결과 기준과 검증 범위

기존 최종 결과는 **II=2, P&R WNS +0.093ns, LUT41,387 / FF41,088 / DSP362**다. HLS 추정과 P&R 수치는 [결과 요약](reports/결과요약.md)에 구분해 두었다. 재실행의 배치·배선 결과는 그 실행 보고서로 다시 판단한다.

이 재현 보관본은 C++ 출력 재현과 합성·구현 실행에 필요한 자료를 담았다. 출력 비교에 쓰는 Python 참조는 저장된 벡터다. PA 모델 학습·추론 환경은 포함하지 않으며, PA 지표를 새로 계산하는 작업은 원래 평가 환경이 필요하다. 최종 후보의 RTL co-sim과 보드 실측은 별도다.

## 재현 보관본 점검

최종 소스·테스트벤치 14개를 원본 해시와 대조했다. 2026-11-04에 이 보관 폴더를 별도 위치로 복사한 뒤, 제공한 `scripts/reproduce.tcl`로 새 프로젝트를 만들고 C-sim을 실행했다.

- 7,680개 입력 모두 처리했고 C-sim 오류는 0개였다.
- 기존 최종 C-sim 출력과 완전히 일치했다. 저장된 Python 참조와도 Q12 기준 불일치는 0개였다.
- [재현 보관본 C-sim 비교 결과](reports/validation/portable_csim_comparison.json)를 함께 넣었다.

같은 소스·입력·재현 스크립트를 별도 위치에서 C-sim까지 실행했다. csynth와 P&R은 기존 조건의 재현 스크립트와 기존 최종 보고서를 제공하며, 재현 보관본으로 다시 실행한 결과는 아니다.

원본 실행 로그: [csynth](logs/csynth.log) · [P&R](logs/impl.log).
