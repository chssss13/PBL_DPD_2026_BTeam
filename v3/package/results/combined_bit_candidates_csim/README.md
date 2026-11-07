# 결합 비트 축소 — C-sim

부모 v2 최종본, DATAFLOW 유지. 입출력 및 bias 15,3과 외부 weight_t 포트는 그대로이며 연산 전 내부에서 가중치·계수를 축소한다. r unsigned12,0; n 및 저장 hidden state13,1; W_inj12,2, W_out11,1, PReLU unsigned11,1, 잔차 unsigned10,0, W_in11,1, W_hn12,2, W_hr/W_hz13,3; 입력 GRU 누산20,5, recurrent r/z19,4, n18,3; amp2 unsigned14,2 및 보간 임시 폭 축소. 구체적 변경은 source.diff 참고.

C-sim 완료: 제공 7680개(15360 성분) Q12 기준 최종 C-sim·Python 참조와 각각 불일치0, 결합 Python 결과와 불일치0. PA 정확도는 Python 결과와 Q12 출력이 같다는 범위에서 이전 Python 재평가 결과와 연결할 수 있다. 모든 입력/가중치에 대한 동등성 증명은 아니다.

csynth, RTL co-sim, P&R 미실시. 입력 계수 포트는 기존 폭이므로 외부 포트 자체의 자원 절감은 실험하지 않았다. 결합 실험이라 각 후보의 효과는 분리하지 못한다.
