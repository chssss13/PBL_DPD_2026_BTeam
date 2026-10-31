# 직접 조회 LUT 간격을 줄인 정확도 개선 실험

2026-10-27. 기존 v1.6 후보를 기준으로 활성화 표 간격만 변경했다.
기존 prj_e07/prj_e08 및 보관 결과는 변경하지 않았고 별도 프로젝트를 생성했다.
재학습, 데이터·가중치·FEx·초기화 조건 변경은 없다.

## 조건과 결과

data_t 16,3 / weight_t 16,4 / accum_t 32,12, 출력층 누산 data_t.
ACT_LUT=2, FEX_INTERNAL_FIXED=1, FEX_INV_I=8, reset_every=2560.
전체 7680샘플. sigmoid/tanh 출력은 16,3 정수 raw 값으로 저장한다.
각 구간 중앙의 함수 값을 사용하며 입력의 하위 SHIFT 비트는 주소에서 제외한다.

| 조건 | SHIFT | 함수당 항목 수 | C-sim PA NMSE | EVM | ACPR L / R | C/Python 비교 NMSE | HLS LOOP_T II |
|---|---:|---:|---:|---:|---:|---:|---:|
| 기존 v1.6, 간격 1/512 | 4 | 4096 | -43.67 | -47.64 | -51.82 / -48.38 | -196.93 | 2 |
| 간격 1/1024 | 3 | 8192 | **-44.94** | -48.85 | -53.05 / -49.57 | -196.94, PASS | **2** |
| 간격 1/2048 | 2 | 16384 | **-45.34** | -49.23 | -53.69 / -50.32 | -196.94, PASS | **2** |

Python 모사의 PA 평가도 각 C-sim 결과와 표시 정밀도에서 동일하다.
두 후보 모두 C-sim 오류 없이 전체 7680샘플 실행을 마쳤고, 비교 전에 파일 형상이 (7680,2)인지 검사했다.
기준 대비 NMSE 개선은 각각 약 1.27 dB, 1.67 dB다.
1/2048 후보는 정확한 활성화/FEx 중간값 기준(-45.48)과 약 0.14 dB 차이,
PyTorch golden(-45.52)과 약 0.18 dB 차이다.
ACPR L의 소폭 개선이 일반적인 우수성을 의미하지는 않는다.

## 합성 설정과 한계

- v1.6과 동일하게 target clock 15 ns, uncertainty 1 ns, DSP_FULL_REG=false, TARGET_II=2.
- 두 후보 모두 실제 LOOP_T achieved II=2, iteration depth=37.
- HLS 추정 clock 13.998 ns, top latency 168 cycles, top interval 128 cycles.
- 두 후보의 HLS 추정치는 LUT 243879, FF 143893, DSP 711, BRAM 0으로 보고됐다.
- 표 항목 수가 달라도 HLS 추정 자원 수치가 같다고 실제 물리 면적이 같다는 의미는 아니다.
  최종 정수 표 선택 회로의 최적화와 배선 비용은 Vivado에서 확인해야 한다.
- 로그의 전체 하위 loop constraint 미충족 문구와 별개로 LOOP_T의 achieved II를 직접 확인했다.
- 이번 후보의 RTL co-sim은 실행하지 않았다. 1/2048 후보의 Vivado 구현 결과는 아래에 별도로 기록한다.
  기존 v1.6의 RTL PASS를 새 후보의 RTL 검증 결과로 대체하지 않는다.
- FEx sqrt/역수 내부 double 계산은 그대로 남아 있다.

따라서 정확도 개선과 HLS II=2 유지는 확인됐지만 15 ns 물리 타이밍 통과를 주장할 수는 없다.
정확도 우선의 후속 검증 후보는 1/2048이며, 최종 선택에는 실제 자원·타이밍 비교가 필요하다.
기존 기본값은 SHIFT=4로 유지한다.

## 1/2048 후보 구현 결과

2026-10-27 실행한 `prj_lut_density_2/sol1` 구현이 중단 요청 전에 완료된 로그를 확인했다. 이번 정리 과정에서는 재실행하지 않았다. export_design 소요 약 1시간 35분 42초, 정상 종료했지만 타이밍은 실패했다.

| 항목 | 1/2048 impl |
|---|---:|
| LUT | 95,426 |
| FF | 48,978 |
| DSP | 711 |
| BRAM / URAM | 0 / 0 |
| SRL | 5,703 |
| Post-Synthesis period | 18.592 ns |
| Post-Route period | 25.245 ns |
| 15 ns 타이밍 판정 | 실패 |

근거: [구현 보고서](../results/lut_density/shift2/implementation/report/export_impl.rpt), [실행 로그](../results/lut_density/shift2/implementation/impl.log). 기존 v1.7의 1/512 결과(LUT 66,859, Post-Route 24.054 ns)보다 자원과 지연이 증가했다. C-sim 정확도 개선을 실제 물리 타이밍 개선으로 해석하면 안 된다.

## 재현

v1 폴더에서 Python 가상환경을 활성화:

```bat
python tools/generate_activation_lut.py
python tools/evaluate_lut_candidate.py --experiment results/lut_density/shift3 --act lut_direct --lut-shift 3
python tools/evaluate_lut_candidate.py --experiment results/lut_density/shift2 --act lut_direct --lut-shift 2
```

Vitis HLS 2024.1 Command Prompt에서 `scripts/run_lut_density.cmd`를 실행한다.
prj_lut_density_3 / prj_lut_density_2에 별도 합성하고 각 실험 결과 경로에 C 출력을 저장한다.

```bat
python tools/validate_candidate.py results/lut_density/shift3 --hls results/lut_density/shift3/hls_out.txt
python tools/validate_candidate.py results/lut_density/shift2 --hls results/lut_density/shift2/hls_out.txt
```

결과·소스·실행 로그·합성 보고서: `results/lut_density/shift3/`, `shift2/`.
초기 Windows 출력 경로 전달 문제는 슬래시 정규화로 수정 후 재실행했다.
표의 모든 C 결과는 수정 후 정상 실행 결과다.
