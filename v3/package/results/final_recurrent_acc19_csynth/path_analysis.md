# C04 routed 최악 경로 확인

2026-11-05. 자동 timing100 추출 전, `prj/sol1/impl/verilog/project.runs/impl_1/bd_0_wrapper_timing_summary_routed.rpt`의 첫 setup 경로를 동일 후보 RTL·스케줄·C++와 대조했다. 전체100경로 분석은 아니다.

- 시작: `ap_enable_reg_pp0_iter6_reg/Q`, 끝: `and_ln223_3_reg_156552_reg[0]/D`.
- WNS−0.423ns, 데이터 경로15.404ns=논리8.000ns+배선7.404ns, 논리56단계. 비교 주기15.423ns와 데이터 경로 지연은 구분한다.
- 연결: enable 선택 논리 → 공유 tanh256 보간 → 상태 갱신 → 상태 bypass/reset/호출 선택 → 공유 z recurrent 곱셈 → 곱 변환·누산·z_pre 변환의 포화 판정 레지스터.

## RTL과 스케줄 근거

`prj/sol1/syn/verilog/ResGRU_Loop_LOOP_T_proc.v` 기준:

1. 31975행 U820의 din0은 `select_ln35_2_reg_156502`, din1은 tanh `fu_6166_ap_return`, din2는 z 입력이다. 출력 `grp_fu_153032_p3`는31979행에서 연결되고75991행의 비트 추출,43633행의 tanh 덧셈과 이후 반올림을 통해 `h_rounded_2_fu_68029_p2`로 이어진다. 이전 h는 등록되어 있지만 tanh와 현재 갱신 결과 사이에 강제 레지스터 경계가 있는 것은 아니다.
2. 36163행의 상태 선택은 현재 `h_rounded_2`와 저장된 상태를 선택한다.63181행의 `select_ln35_2`는 이 값과 reset0을 선택한다. 이 조합논리 출력이37599행에서 z 곱셈기 `fu_5637`의 x로 연결된다.
3. 37585~37603행에서 같은 곱셈기는 `select_ln35_7`/`select_ln35_2`와 등록된 가중치 `p_read_325...`/`p_read_144...`를 실행 상태에 따라 선택한다. 자원 공유 및 현재 상태 bypass가 함께 존재한다. 곱셈 하위 모듈은 x/w→mul→ap_return으로 연결되고 클록 입력이 없다. routed 경로도 두 DSP의 조합 포트를 지나며 중간 FD 레지스터를 통과하지 않는다.
4. C++ `gru_cell.h:166`의 `Recurrent_Gate_MVM<1>`은 W_hz 연산이다. 곱셈 이름만으로 판단하지 않고 게이트 매핑을 확인했다.
5. 끝점 `and_ln223_3`는32498행에서 레지스터로 저장된다. `.autopilot/db/Loop_LOOP_T_proc.verbose.sched.rpt:9115`는 해당 op9016을 ST9, `gru_cell.h:223`에 연결한다.223행은 `z_pre = W_iz_x[i] + b_iz_local[i] + W_hz_h[i] + b_hz_local[i]`다.62971~62993행은 등록된 판정으로 Q3.12 한계값16383/16384와 계산값을 선택한다. 따라서 끝은 sigmoid 조회 자체가 아니라 sigmoid에 넣기 전 z_pre 변환의 포화 판정이다.

물리 net 이름에는 다른 공유 연산의 이름도 섞여 있으므로 같은 샘플이 이 모든 수식을 순서대로 수행한다고 단정하지 않는다. 단순 mux 지연만도 아니며 tanh·상태 갱신·행렬곱·변환 산술이 한 레지스터 간 경로에 연결되어 있다.

## 기준 최종본과 비교

| 지표 | 기준 최종본 | C04 |
|---|---:|---:|
| 데이터 경로 | 14.888ns | 15.404ns |
| 논리 지연 | 7.851ns | 8.000ns |
| 배선 지연 | 7.037ns | 7.404ns |
| 논리 단계 | 53 | 56 |
| 끝점 역할 | r_pre 포화 판정 | z_pre 포화 판정 |

최악 경로 지연은0.516ns 증가했고 그중 논리+0.149ns, 배선+0.367ns다. 시작·끝점이 다른 각 구현의 최악 경로 비교이므로 누산 폭 변경 자체의 단독 지연으로 해석하지 않는다. 새롭게 sigmoid 조회가 병목이 된 것이 아니라 기존 tanh→상태→recurrent 계열에서 z 쪽이 최악으로 올라왔다. 폭 축소가 LUT 증가나 경로 악화를 일으킨 세부 최적화 원인은 이 확인만으로 확정하지 않는다.
