# P2: 2,560샘플 구간 상태 리셋

**한 줄 요약:** P2 리셋을 2,560샘플 구간으로 바꾸고 C-sim과 Python 일치를 확인했다.

64샘플 블록 단위 처리를 유지하면서 구간 시작 신호가 참인 블록의 첫 샘플에서 은닉 상태를 초기화한다. 테스트벤치가 2,560샘플 구간 시작을 전달한다.

## 결과

| 항목 | 결과 |
|---|---:|
| C-sim | 7,680샘플, 오류 0건 |
| C-sim ↔ Python 참조 | NMSE -81.45 dB, PASS (기준 -60 dB) |
| 최대 절대 오차 | 2.441e-04 (t=871) |
| PA NMSE | -27.27 dB |
| PA EVM | -28.62 dB |
| PA ACPR L / R | -42.31 / -37.94 dBc |

참조 대비 NMSE와 PA 통과 NMSE는 다른 지표다. C-sim과 Python 출력의 PA 수치는 표시된 소수점 둘째 자리까지 같다. 합성 II·자원 및 P&R 타이밍은 이번 변경에 대해 아직 측정하지 않았다.

## 보관 파일

- `ref_reset2560.txt`: Python 참조 출력 (fxp hls, act hard, fex nr_fx, reset_every 2560)
- `hls_out.txt`: RESET_ARG를 켠 C-sim 출력
- 과정과 PA 평가 내역: 저장소 루트 `v1_작업메모.md`

## 재현 시 주의

변경된 ResGRU는 구간 시작 입력을 받으므로 테스트벤치와 함께 실행할 때 반드시 `RESET_ARG`를 설정해야 한다. VS Code PowerShell, `package` 폴더 기준:

```powershell
$env:RESET_ARG = '1'
$env:STEPS = 'csim'
cmd /c "call C:\Xilinx\Vitis_HLS\2024.1\settings64.bat && vitis_hls -f scripts/run_resgru.tcl"
python tools/compare_out.py results/hls_out.txt results/ref_reset2560.txt --nmse_max -60
```

`ref_reset2560.txt`는 실행 전에 생성하거나 이 폴더에서 `package/results`로 복사한다. HLS 스크립트는 `prj_resgru`를 초기화하고 `results/hls_out.txt`를 덮어쓴다. 기존 `wrapper.cpp`는 이 C-sim 빌드 대상이 아니며 변경된 인터페이스에 대한 수정·검증이 필요하다.
