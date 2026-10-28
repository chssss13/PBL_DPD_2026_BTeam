# Verilog RTL co-simulation

2026-10-29. HLS II=2 조합 조회 실험의 기존 합성 프로젝트를 초기화하지 않고 XSim Verilog co-sim을 실행했다. 테스트벤치에서 Windows stdio 파일 한도를 2048로 늘렸으며 DUT 소스와 합성 결과는 바꾸지 않았다. 전체 7,680샘플, 120개 64샘플 블록, 2,560샘플 구간 시작에서 리셋했다.

- C/RTL co-simulation PASS. RTL 출력과 기존 C-sim 출력의 수치가 7,680샘플 모두 일치했다.
- RTL 출력 vs Python 참조: NMSE -196.85 dB, 최대 오차 5.000e-11, PASS. 파일 출력 자릿수 차이로 수치 불일치는 7,563샘플이다.
- RTL 출력 PA 평가: NMSE -43.57 dB, EVM -47.70 dB, ACPR L/R -51.26 / -48.02 dBc. 세 가지 정확도 기준을 통과했다.
- Co-sim 보고서의 64샘플 최상위 호출 latency는 148 cycles, 호출 interval은 134 cycles다. 블록 단위 핸드셰이크를 포함한 이 간격은 샘플 루프의 HLS II=2와 다르다.
- 이후 Vivado 배치·배선 결과 주기 17.506 ns로 목표 15 ns에 미달했다. [구현 결과](../implementation/README.md)

`cosim.log`, 보고서, RTL 출력, 비교·PA 평가 및 테스트벤치와 실행 스크립트를 함께 보관한다.
