# 은닉 상태 갱신 수식 실험: HLS 합성

2026-10-29. 활성화 함수 LUT 4096칸과 BRAM 조회는 유지하고 은닉 상태 갱신을 `n + z * (h_prev - n)`으로 변경했다. data 16,3 / weight 16,4 / accum 18,3, FEx 역제곱근 16,6, 2560샘플 초기화. HLS 목표 15ns, uncertainty 1ns, DSP full reg false, LOOP_T II=2 요청.

- C-sim 7,680샘플, 오류 0. 변경 전 C++ 출력과 파일 내용이 같았다. Python 비교 NMSE -196.85dB, PASS.
- csynth 정상 종료. LOOP_T achieved II=3, depth 19.
- HLS 추정 주기 13.961ns, LUT 197,736, FF 147,433, DSP 692, BRAM_18K 160.
- `All loop constraints were NOT satisfied` 경고가 남았다. RTL co-sim과 P&R은 미진행.

보고서, 로그, C-sim 출력과 당시 소스를 함께 보관한다. 해당 수식과 활성화 조회 변경을 함께 적용한 다음 실험은 [조합 조회 결과](../p1_lut4096_comb_ii2_csynth/README.md)다.
