# E20 새 clone에서 재현하기

## 준비

Windows CMD에서 실행합니다. Vitis HLS 2024.1, Vivado 2024.1과 XCZU7EV 디바이스 지원이 필요합니다. 아래 Xilinx 설치 경로는 자신의 설치 위치로 수정하세요. Python 검증 스크립트는 표준 라이브러리만 사용합니다.

`src_snapshot/` 전체와 `tb_snapshot.cpp`가 고정 구현 입력입니다. 가중치·입력 벡터는 이미 저장소에 있는 `package/golden/`을 사용합니다. 스크립트가 작업 `package/src`를 참조하지 않으므로 다른 실험 소스에 영향을 받지 않습니다.

```bat
cd /d C:\PBL_DPD_2026_BTeam\package
python results\E20_input_precompute\verify_shared.py
call C:\Xilinx\Vitis_HLS\2024.1\settings64.bat
vitis_hls -f scripts/run_e20_csim.tcl
vitis_hls -f scripts/run_e20_csynth.tcl
vitis_hls -f scripts/run_e20_cosim.tcl
vitis_hls -f scripts/run_e20_export.tcl
call C:\Xilinx\Vivado\2024.1\settings64.bat
vivado -mode batch -notrace -source scripts/run_vivado_e20.tcl
```

위 순서는 새 clone 기준입니다. 이미 E20 프로젝트나 결과가 있는 작업 공간에서는 별도 clone을 사용하세요. 실행 시 이 폴더의 `precomputed.txt`, `rtl_out.txt`, 보고서와 복제 대상 목록 등이 새 실행 결과로 갱신됩니다. 이전 값은 Git 커밋으로 보존됩니다. 실행 전에 비교 기준 벡터를 복사해 두세요.

```bat
copy results\E20_input_precompute\precomputed.txt results\e20_archived_reference.txt
```

## 각 단계에서 확인

- C-sim: 7,680샘플, 2,560샘플마다 reset. 보존한 기준과 Q14 코드 비교.
- C 합성: `prj_csim_e20_precompute/sol1/syn/report/Loop_LOOP_T_proc_csynth.xml`에서 `LOOP_T`의 `PipelineII=2` 확인.
- RTL co-sim: `sol1/sim/report/ResGRU_cosim.rpt`에서 Verilog `Pass` 확인. 2,624샘플로 reset 경계 포함.
- Vivado: `route/`와 `postroute/`의 실제 자원·타이밍·배선·DRC 보고서 확인. HLS 추정값을 실제 자원으로 사용하지 않습니다.
- 구현에는 Explore opt/place/route, 최대 8개 임계 데이터 net 드라이버 복제, AggressiveExplore phys_opt, 배선 후 Explore를 적용합니다. 선택 대상과 결과는 새 배치에 따라 달라질 수 있습니다.

보존한 기준 벡터와 새 벡터는 `package/tools/compare_out.py`로도 비교할 수 있습니다. 해당 도구는 NumPy가 필요합니다. `verify_shared.py`는 자료 해시와 동봉 벡터 일치를 검증하는 도구이며, 합성·RTL 시뮬레이션이나 PA 모델 재평가를 대신하지 않습니다.

PA 재평가를 원하는 경우 저장소의 `package/tools/eval_pa.py`, `package/opendpd_min/` PA 체크포인트와 데이터셋을 사용합니다. 학습 환경 의존성은 별도 설치가 필요하며 HLS/Vivado 구현 자체에는 Python PA 환경이 필요하지 않습니다.

```bat
cd opendpd_min
python ../tools/eval_pa.py --pa save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt ../golden/vectors/torch_out.txt ../results/E20_input_precompute/precomputed.txt
```

## 동봉 파일의 의미

- `evaluation.json`: 최초 C-sim/PA 단계 기록. 당시 `implementation_run=false`는 이후 완료 상태와 구분합니다.
- `hls_evaluation.json`, `rtl_evaluation.json`, `ResGRU_cosim.rpt`: 후속 C 합성·RTL 검증 근거.
- `implementation_evaluation.json`, `IMPLEMENTATION_RESULTS.md`, `route/`, `postroute/`: 완료된 실제 구현 근거. JSON 내부 절대 경로는 원래 실행 PC의 이력이며 재현 경로로 사용하지 않습니다.
- `source_hashes.json`: 구현에 사용한 C/C++ 소스 SHA-256.
- `PA_EVALUATION.txt`: 제공 PA 모델 평가 원본 출력.

생성 프로젝트, DCP, Vivado 캐시, 진행 상태와 완료 마커는 공유하지 않습니다. 완료 마커를 재사용하는 로컬 Python 실행기 대신 위 Tcl 순서로 새로 실행하세요.
