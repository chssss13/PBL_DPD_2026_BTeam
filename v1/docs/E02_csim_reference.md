# E02: 정확도 참조 C 버전과 Python 비교

2026-10-16, Vitis HLS 2024.1 Windows, 7680샘플 전체 C-sim 완료.

## 변경

- data_t = ap_fixed<16,3>, weight_t = ap_fixed<16,4>, accum_t = ap_fixed<32,12>.
- GRU sigmoid/tanh는 double 수학 함수로 계산한 후 data_t로 양자화.
- FEx는 double sqrt/나눗셈을 사용하고 각 출력에서 data_t로 양자화.
- ResGRU에 bool reset 인자 추가. 블록 첫 샘플에서 reset이 참인 경우만 상태 초기화.
- Tcl에서 RESET_ARG를 항상 정의해 기존 TB가 2560샘플 구간 시작을 전달하도록 설정.
- v0 package와 golden은 수정하지 않음.

이 버전은 Python에서 통과한 계산의 C-sim 재현용이다. double 내부 연산을 포함하므로
전체 연산이 16비트인 하드웨어라고 해석하면 안 된다. 합성/RTL/II/자원/타이밍은 아직 검증하지 않음.
기존 wrapper.cpp는 빌드 대상이 아니며, 변경된 reset 인터페이스 대응은 별도 필요.

## 결과

- CSim done with 0 errors, 7680샘플, csim_design 약 2분 15초.
- C와 Python 비교: NMSE -196.88 dB, PASS (기준 <= -60 dB).
- 최대 파일상 오차 5e-11. 텍스트 출력 소수 자릿수 차이가 있어 저장 파일의 완전 일치는 아님.
- C-sim PA 평가: NMSE -45.48 dB, EVM -49.34 dB, ACPR L/R -53.33/-50.37 dBc.
- Python PA 평가도 표시 정밀도에서 동일. 필수 정확도 세 기준 모두 통과.

## 재현 (Vitis HLS 2024.1 Command Prompt, v1 폴더)

```bat
set STEPS=csim
set NT=7680
set FEX_INTERNAL_FIXED=0
vitis_hls -f scripts/run_resgru.tcl > results/csim_reference.log 2>&1
call C:\Project\venv_dpd\Scripts\activate.bat
python tools/verify_reference.py
```

검증 스크립트는 매번 현재 hw_ref.py로 참조를 다시 만들고 7680x2 형상을 확인한 뒤
compare_out.py와 eval_pa.py를 실행한다. 원시 결과는 results/E02_csim_reference/에 저장.
기존 results/hls_out.txt는 C-sim을 재실행하면 덮어써진다.

E04 이후 기본 FEx는 16비트 중간값 후보로 변경되었다. 이 E02 실험 재현에는
반드시 위 FEX_INTERNAL_FIXED=0을 지정한다. E04의 환경변수도 동일 Tcl에 기록된다.

다음은 정확도 여유를 유지하면서 double 활성화/FEx를 하드웨어 구현에 적합한 계산으로
대체하는 실험과, 합성 후 II 및 구현 비용 검증이다.
