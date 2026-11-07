# v3 후보 통합 기록

미채택 후보를 빠르게 보려면: [v3 미채택 실험 요약](미채택_실험요약.md) — 변경 내용·기각 이유·보류 상태.

현재 채택본: **[v3.2](v3.2/README.md)**. 이전 채택본: **[v3.1](v3.1/README.md)**. v3는 이 실험 계열 전체이며 별도 v3.0 채택본은 없다.

아래는 실험 진행 당시 기록을 누적한 내용이다. 같은 후보의 과거 ‘진행 중·미실시·채택 미정’ 표기는 뒤에 추가된 완료·채택 기록과 구분한다. 현재 채택본 상태는 위 버전별 README를 우선한다.


2026-11-05 기준. csynth까지 진행한 후보를 유지·기각과 무관하게 기록한다. 결과는 해당 시점의 완료된 보고서에서 확인했으며 이후 P&R·판단을 추가한다.

공통 기준은 [v2 최종 채택본](../../v2/result/final/README.md)이다. 대상 `xczu7ev-ffvc1156-2-e`, Vitis HLS / Vivado 2024.1, 15ns 클록, HLS uncertainty 1ns, DSP full reg false, LOOP_T II=2 요청. 두 BRAM 후보는 **동일 기준본에서 각각 분기**했으며 서로 누적되지 않았다.

## 후보와 현재 판단

C11: [외부 I/Q13,1](../package/results/final_io13_csynth/README.md)을 v2 최종본에서 독립 준비하여 C-sim·csynth 완료. 7,680개 출력 일치, II2/Depth18, 13.881ns, LUT222,652/FF127,948/DSP499/BRAM0. 기준 HLS 대비 LUT+282/FF−32/DSP+10. P&R 미실시, 판단 미정. 내부 data15,3과 출력층 MAC은 유지하고 경계에서만 변환한다. 자원 증가 원인은 미확정이다.

C10 csynth 완료: II3/Depth21,13.999ns,LUT138865/FF18095/DSP411/BRAM0. 부모 C06 대비 LUT−130/FF−405이며 II2 회복에는 실패했다. top latency219/interval220클록으로 C06보다 각각3클록 늘었다. P&R 미실시, 채택 판단 미정. 상세 결과는 C10 README 참조.

C10: [C06 시간 루프·상태 함수 경계 변경](../package/results/final_no_top_dataflow_state_scope_csim/README.md)은 C-sim 7,680개 일치 후 사용자 요청으로 csynth를 시작했다. C06에서 독립 분기하며 C07/C08 분리나 C09 remap은 포함하지 않는다. 기존 `_csim` 폴더명을 유지하고 `csynth.log`에 합성 로그를 별도 기록한다.

C09 사용자 판단: ExploreWithRemap 결과는 보존하고 **최종 RTL 확정 후 기본 설정과 재비교할 옵션**으로 둔다. 후속 C++/HLS 실험에는 자동 적용하지 않는다. 이번 P&R은 LUT41,240/FF41,017/DSP362/BRAM0, WNS+0.198ns이며 기존 최종본 대비 LUT−147/FF−71의 소폭 개선이다.

C09 초기 실행은 packaged IP HDL 누락으로 합성 시작 전에 실패했다. 초기 COMPLETE 표시는 잘못된 것으로 정정했다. 동일 기준 RTL에서 133개 누락 파일을 복구하고 전체 패키지 참조를 검증한 [retry01](../package/results/final_opt_remap_pnr_retry01/README.md)에서 재실행한다. 최적화 설정·RTL 설계 변경은 추가하지 않았다.

최신 실행: 사용자가 N1 보류를 해제하여 [C09 / ExploreWithRemap](../package/results/final_opt_remap_pnr/README.md)을 시작했다. v2 최종 packaged IP를 보존 복사하고 opt_design directive만 바꾸는 독립 P&R이다. DATAFLOW 제거 후보의 변경은 포함하지 않는다. 합성 결과는 기존 HLS 결과를 계승하며 Vivado RTL 합성부터 실행한다.

| ID | 후보 | C-sim | csynth | P&R | 판단 |
|---|---|---|---|---|---|
| [C01](c01_sigmoid_bram/README.md) | sigmoid 256구간 보간 표 BRAM | 7,680개 Q12 일치 | 완료, II=2 | 완료, 15ns 미달 | 미정 |
| [C02](c02_tanh_bram/README.md) | tanh 256구간 보간 표 BRAM | 7,680개 Q12 일치 | 완료, II=2 | 미실시 | 미정 |
| [C03](c03_r_unsigned12/README.md) | r 곱셈 입력 unsigned12 | 7,680개 Q12 일치 | 완료, II=2 | 완료, 15ns 통과 | 미채택, 기존본 유지 |
| [C04](../package/results/final_recurrent_acc19_csynth/README.md) | recurrent 누산21,6→19,4 | 7,680개 Q12 일치 | 완료, II=2 | 완료, WNS−0.423ns | 미채택, 기존본 유지 |
| [C05](../package/results/final_input_acc20_csynth/README.md) | 입력 MAC 누산21,6→20,5 | 7,680개 Q12 일치 | 완료, II=2 | 보류·미실시 | csynth 완료 후보로 보관 |
| [C06](../package/results/final_no_top_dataflow_csynth/README.md) | 최상위 DATAFLOW 제거 | 7,680개 Q12 일치 | 완료, II=3 | 미실시 | 자원 감소, 처리율 목표 미달·판단 미정 |
| [C07](../package/results/final_no_top_dataflow_tanh_layer_split_csynth/README.md) | C06 + tanh 레이어 공유 분리 | 실행 상태는 후보 로그 참고 | C-sim 통과 후 병렬 실행 요청 | 미실시 | II2 회복 검토 |
| [C08](../package/results/final_no_top_dataflow_r_layer_split_csynth/README.md) | C06 + r recurrent 곱셈 레이어 공유 분리 | 실행 상태는 후보 로그 참고 | C-sim 통과 후 병렬 실행 요청 | 미실시 | II2 회복 검토 |

C07/C08은 2026-11-05 사용자 요청으로 같은 C06에서 독립적으로 분기해 C-sim→csynth를 병렬 시작했다. 두 변경을 결합하지 않았으며, 수치 연산과 자료형은 유지한다. v2 최종 채택본은 유지하고 N1 P&R은 계속 보류한다. II2 실패의 직접 경고는 tanh와 recurrent 누산 사이 반복 의존성이므로, 연산기 분리로 해결될지는 결과로 확인한다.

C01의 첫 P&R은 IP 생성 중 Vivado 비정상 종료로 실패했다. 합성 프로젝트를 별도 복사해 재시도했고 정상 완료됐다. 재시도 결과는 15ns 타이밍 미달이다. 첫 시도 실패는 타이밍 미달을 뜻하지 않는다.

## HLS 추정 비교

| 후보 | 추정 주기 | LOOP_T II / Depth | LUT | FF | DSP | BRAM_18K |
|---|---:|---:|---:|---:|---:|---:|
| 기준 최종본 | 13.881ns | 2 / 18 | 222,370 | 127,980 | 489 | 0 |
| C01 sigmoid BRAM | 13.840ns | 2 / 22 | 203,116 | 128,576 | 551 | 15 |
| C02 tanh BRAM | 13.881ns | 2 / 18 | 208,836 | 127,946 | 491 | 10 |
| C03 r unsigned12 | 13.881ns | 2 / 18 | 221,755 | 127,920 | 489 | 0 |
| C04 recurrent 누산19,4 | 13.881ns | 2 / 18 | 225,475 | 127,980 | 489 | 0 |
| C05 입력 누산20,5 | 13.840ns | 2 / 18 | 222,010 | 127,980 | 489 | 0 |
| C06 최상위 DATAFLOW 제거 | 13.999ns | 3 / 21 | 138,995 | 18,500 | 411 | 0 |

C03도 v2 최종본에서 독립 분기했다. 기준 대비 LUT615개·FF60개 감소, DSP 동일이다. BRAM이나 비균일 tanh 변경은 포함하지 않았다.

자원과 타이밍은 HLS 추정끼리 비교했다. 배치·배선 후 수치는 별도로 기록한다. 추정 주기의 작은 차이로 P&R의 우열을 단정하지 않는다. 두 후보 모두 표 값과 보간 산술을 유지했으나 BRAM 1클록 조회를 허용하기 위해 선택한 함수의 기존 0클록 제약도 해제했다.

기준 P&R은 14.907ns(`15−WNS`), WNS +0.093ns, LUT 41,387 / FF 41,088 / DSP 362 / BRAM 0이다. 데이터 경로 지연은 14.888ns다. 기준 최종본의 RTL co-sim은 별도 재합성 후 7,680개 PASS이며 재생성된 RTL은 주석·공백을 제외하고 기존 RTL과 일치했다. [로컬 co-sim 기록](../../v2/package/results/final_cosim_20261105/README.md).

## P&R 비교

| 후보 | WNS | 비교 주기 | LUT | FF | DSP | RAMB18 | BRAM tile |
|---|---:|---:|---:|---:|---:|---:|---:|
| 기준 최종본 | +0.093ns | 14.907ns | 41,387 | 41,088 | 362 | 0 | 0 |
| C01 sigmoid BRAM | −0.851ns | 15.851ns | 40,049 | 41,332 | 393 | 15 | 7.5 |
| C03 r unsigned12 | +0.052ns | 14.948ns | 41,297 | 41,156 | 362 | 0 | 0 |
| C04 recurrent 누산19,4 | −0.423ns | 15.423ns | 44,599 | 41,239 | 362 | 0 | 0 |

C01은 LUT가 1,338개 줄었고 FF 244개·DSP 31개·RAMB18 15개가 늘었다. 15ns setup 위반은 394개, hold 위반은 0개다. 결과와 후보 채택 여부는 구분한다.

C03은 LUT90개 감소, FF68개 증가, DSP·BRAM 동일이다. setup/hold 위반0으로 통과했으나 WNS 여유는 기준보다0.041ns 줄었다. 사용자가 기존 v2 최종본 유지를 선택해 미채택으로 기록했다.

## 앞으로 기록할 항목

### C06 HLS 완료

사용자 요청으로 [C06 최상위 DATAFLOW 제거](../package/results/final_no_top_dataflow_csynth/README.md)를 별도 프로젝트에서 C-sim→csynth 실행했고 정상 완료했다. 부모는 v2 최종본이며 C04/C05 변경은 누적하지 않았다. LUT−83,375/FF−109,480/DSP−78이지만 LOOP_T II3으로 처리율 목표를 유지하지 못했다. HLS top latency216/interval217클록, P&R·RTL co-sim 미실시, 채택 미정이다. N1 Vivado 논리 재매핑 P&R은 사용자 요청으로 보류한다.

### C05 HLS 완료

2026-11-05 사용자 요청으로 [C05 입력 GRU 누산20,5](../package/results/final_input_acc20_csynth/README.md)를 C04 P&R과 병행 실행했다. v2 최종본에서 독립 분기하고 입력 누산형 한 줄만21,6→20,5로 변경했다. C-sim7,680개 출력 일치, csynth 정상 완료다. 기준 대비 HLS LUT360개(0.16%) 감소, 추정 주기0.041ns 감소이며 다른 자원·II·Depth는 동일하다. 해당 후보 P&R은 미실시이며 채택 미정이다.

### C04 완료 결과

2026-11-05 [C04 recurrent 누산19,4](../package/results/final_recurrent_acc19_csynth/README.md)는 C-sim7,680개에서 최종본과 완전히 일치했고 csynth와 P&R도 정상 완료했다. 입력 측 누산은21,6으로 유지하고, 미채택 C03의 r 변경은 포함하지 않았다. 기준 대비 HLS LUT3,105개(+1.40%) 증가, FF·DSP·BRAM·II·Depth·추정 주기는 동일하다. 최종 routed LUT+3,212/FF+151, WNS−0.423ns로 타이밍 미달이며 사용자 요청으로 미채택했다. [경로 분석](../package/results/final_recurrent_acc19_csynth/path_analysis.md).

각 후보마다 기준 소스, 변경과 목적, 실행 조건, C-sim·csynth·P&R 결과, 후속 선택과 이유, 미실시 검증을 남긴다. 시도했으나 기각한 후보도 기록하며 P&R을 하지 않았다면 ‘미실시’로 둔다. HLS 추정과 실제 배치·배선 후 자원은 서로 직접 비교하지 않는다.

## C12 — recurrent 중간 누산 포화 제거 (2026-11-06)

[P09 단독 후보](../package/results/final_recurrent_acc_nosat_csynth/README.md)를 v2 최종본에서 준비해 C-sim→csynth 실행을 요청했다. recurrent r/z/n 누산21,6의 AP_SAT만 AP_WRAP으로 변경하고 DATAFLOW·입력 MAC·항별 및 최종18,3 포화는 유지한다. 출력 검증 실패 시 합성하지 않는다. 진행 상태는 후보 status.txt/csynth.log를 확인한다. P&R 미실시, 채택 미정.

### C12 완료 / C13 실행 (2026-11-06)

C12: C-sim7680개 Q12 일치, csynth9분21초 정상 완료. II2/Depth18/13.881ns,LUT221290/FF127980/DSP489/BRAM0. 기존 최종본 대비 LUT1080개 감소, 다른 요약 수치 동일. P&R 미실시.

[C13](../package/results/final_recurrent_acc_nosat_no_top_dataflow_csynth/README.md)은 사용자 요청으로 C12에서 최상위 DATAFLOW만 제거한 결합 후보다. C12 소스와 실행 설정을 복사하고 해당 pragma 한 줄만 제거했다. C-sim 출력 검증 후 csynth 진행. II2 회복 여부 미확정, P&R·co-sim 미실시. 기존 최종본 유지.

### C14 uncertainty 0ns 실행 (2026-11-06)

[C14](../package/results/final_recurrent_acc_nosat_no_top_dataflow_unc0_csynth/README.md)는 사용자 병렬 실행 요청으로 C13의 소스·테스트벤치를 그대로 복사하고 HLS uncertainty만1ns→0ns로 변경했다. 15ns 클록과 다른 조건 유지. C-sim 검증 후 csynth 실행하며 기존 C13은 보존한다. 최종 II·자원은 완료 후 확인, P&R 미실시.

### C13/C14 완료 결과 (2026-11-06)

| 후보 | II/Depth | 추정 ns | LUT | FF | DSP | BRAM |
|---|---|---:|---:|---:|---:|---:|
| C13 중간 포화 제거+DATAFLOW 제거, uncertainty1ns | 3/21 | 13.999 | 133820 | 18503 | 411 | 0 |
| C14 동일 소스, uncertainty0ns | 3/20 | 14.965 | 133874 | 19063 | 411 | 0 |

둘 다 정상 완료, II2 회복 실패. C13은 C06 대비 LUT5175 감소지만 II3 유지. C14는 C13 대비 LUT54/FF560 증가. P&R 미실시, 실제 구현 타이밍 미확정. 기존 최종 채택본 유지.

### C15/C16 클록 완화 진단 — 사용자 정정 반영

2026-11-06 C14 동일 소스로16ns(C15)/18ns(C16) 병렬 csynth를 시작했다. 사용자가 uncertainty1ns를 요청해 최초0ns 실행 두 개를 중단하고 로그를 보존했다. 실제 평가 대상은 `final_recurrent_acc_nosat_no_top_dataflow_clk16_unc1_csynth` 및 `final_recurrent_acc_nosat_no_top_dataflow_clk18_unc1_csynth`이다. 두 후보 모두 uncertainty1ns, II2 요청을 유지한다. C13(15ns/1ns)과 비교하면 클록만 바뀐다. C14와 소스·TB 해시 일치 검증 후 기존 C-sim7680개 결과를 승계했으며 C-sim 재실행·P&R은 하지 않는다. 최초 중단 폴더는 별도 완료 후보가 아니다.

C15 결과: 16ns / uncertainty1ns에서 csynth 완료, LOOP_T II3/Depth20, 추정14.965ns, LUT133874/FF19063/DSP411/BRAM0. 15ns / uncertainty0ns의 C14와 요약 수치가 같고 II2는 달성하지 못했다. C16(18ns)은 확인 당시 진행 중이며 결과 미확정. P&R 미실시.

### C17 결합 비트 축소 csynth 실행 (2026-11-06)

[결합 C-sim 소스](../package/results/combined_bit_candidates_csim/README.md)를 SHA256 일치 확인하여 [별도 C17](../package/results/combined_bit_candidates_csynth/README.md)로 복사했다. C-sim 검증은 부모에서 승계, 15ns/uncertainty1ns/II2 요청 조건으로 csynth만 실행한다. P&R 미실시, 채택 미정.

C16 HLS 완료: 18ns / uncertainty1ns에서 LOOP_T II2 / Depth17, 추정16.939ns, LUT150370 / FF18603 / DSP486 / BRAM0. 사용자 요청으로 동일 후보 18ns 제약 P&R 및 setup 경로100개 추출을 시작했다. C15와 C16은 15ns 과제조건을 충족한 결과가 아니다.

C16 첫 P&R은 Vivado IP 생성 중 EXCEPTION_ACCESS_VIOLATION으로 종료되어 구현 타이밍 결과가 없다. 로그와 덤프 보존 후 동일 HLS 프로젝트/RTL을 c16_pnr_retry01로 복사해 재시도한다. 원인 확정 불가, HDL/data SHA256 일치 확인,18ns 조건 유지.

C16 P&R retry01도 IP 생성 단계에서 실패했다. 이번에는 사용자 설정 경로 `C:/Users/user/AppData/Roaming/Xilinx/Vivado/2024.1/Vivado_init.tcl` 확인 시 접근 거부가 명시됐다. 동일 프로젝트/RTL을 c16_pnr_retry02로 보존 복사하고 권한 확장 실행을 시작했다. 최초 access violation의 직접 원인까지 확정한 것은 아니다. 타이밍 결과 없음; 최신 실행 로그는 c16_pnr_retry02/impl.log.

C17 HLS 완료: II2/Depth19,13.992ns,LUT277580/FF202179/DSP534/BRAM0. 기준 대비 LUT+55210/FF+74199/DSP+45. 내부 계수 축소용 복사 루프가 DATAFLOW 프로세스로 분리돼 채널 비용 증가가 함께 측정됐다(프로세스2→7, FIFO LUT+25594/FF+37818). 전체 증가의 원인을 이것만으로 단정하지 않으며, 순수 비트 축소 효과와 구현 구조 효과를 분리하지 못한다. C-sim 일치, P&R 미실시.

### C16 P&R 완료 — DATAFLOW 제거 방향 미채택

18ns 조건의 [retry02](../package/results/c16_pnr_retry02/README.md)는 WNS−79.116ns, 비교주기97.116ns, LUT23356/FF7574/DSP502/BRAM0. 합성 후에도93.405ns여서 배선만의 문제가 아니다. 최악100경로는 모두 FEx NR의 공유 곱셈기 쌍을 통과한다. RTL 레지스터와 routed DSP 비등록 B→ALU→P 경로를 확인했다. [분석](../package/results/c16_pnr_retry02/path_analysis.md). 사용자 요청으로 현재 DATAFLOW 제거 방향은 미채택·보류, 기존 최종본 유지. C17 결합 축소는 별도 후보다.

### C18/C19 FEx sqrt·나눗셈 비교 시작 (2026-11-06)

최종 v2에서 FEx만 현서님 방식으로 교체한 병렬 대안이다. C18은 역수16,6, C19는16,8. data15,3·weight14,4·DATAFLOW·활성화256 유지, 15ns / uncertainty1ns / 목표 II2 / DSP full register false. Python PA 비교는 `package/results/fex_sqrt_python/README.md`에 보존했다.

- [C18](../package/results/final_fex_sqrt_inv6_csynth/README.md)
- [C19](../package/results/final_fex_sqrt_inv8_csynth/README.md)

각 후보의 C-sim 전체7680개 출력이 해당 Python 후보와 Q12 일치한 경우에만 csynth로 이어진다. 기존 NR4 출력과의 일치를 요구하는 실험은 아니다. 두 후보 실행 시작 및 C-sim 컴파일 진입 확인. P&R 미실시, 채택 미정. 실제 완료 상태는 각 폴더 status.txt/csim_comparison.json/csynth.log에서 확인한다.

C18/C19 HLS 완료: 양쪽 C-sim7680개 Python 후보 참조와 Q12 일치. 공통 II2/Depth38,13.924ns,FF128774/DSP478/BRAM0,호출169cycle/간격128cycle. LUT는 C18 226088, C19 226094. 최종 v2 대비 DSP−11, FF+794, LUT+3718/+3724, 추정주기+0.043ns. P&R 미실시, 채택 미정.


C19 P&R 시작(2026-11-06): 사용자 요청,15ns 표준 HLS export implementation 경로. 기존 csynth 보존, 완료 후 setup100경로와 자원 추출. C18은 HLS 결과만 보존. 결과 미확정.


C19 P&R 완료:15ns WNS+0.064457ns,WHS+0.019ns,미배선0,비교주기14.936ns. LUT47240/FF42738/DSP347/BRAM0. 최종 v2 대비 LUT+5853,FF+1650,DSP−15. setup100경로 보존 완료. IP 내부 타이밍 통과,외부I/O 통합은 별도. 채택 미정.


### C20/C21 NR 반복 축소 실행 (2026-11-06)

최종 v2에서 NR 반복만4→3회(C20),4→2회(C21)로 변경한 병렬 대안. inverse16,6/data15,3/weight14,4/DATAFLOW 유지. 15ns/uncertainty1ns/목표 II2/DSP full register false. Python PA 결과는 nr_iterations_python에 보존. 각 해당 Python 참조와 C-sim7680개 Q12 일치 확인 후 csynth를 자동 진행하며 불일치 시 중단한다.

- [C20 NR3](../package/results/final_nr3_csynth/README.md)
- [C21 NR2](../package/results/final_nr2_csynth/README.md)

기존 소스·결과 보존, P&R 미요청, 채택 미정. 실제 진행 상태는 각 status.txt/csim_comparison.json/csynth.log 확인.

C20/C21 모두 C-sim7680개 해당 Python 참조와 Q12 불일치0 확인, 병렬 csynth 진입 확인. 결과 대기 중.


C20/C21 csynth ??: ? ? C-sim ?? Python ??? 7,680? Q12 ??, LOOP_T II2, ?? 13.881ns/72.04MHz. C20 NR3 Depth17, LUT221973/FF127626/DSP488/BRAM0, ??148cycle. C21 NR2 Depth16, LUT220916/FF126838/DSP482/BRAM0, ??147cycle. ? ? ?? ??128cycle. ?? v2 ?? C20 LUT?397/FF?354/DSP?1, C21 LUT?1454/FF?1142/DSP?7. P&R ?????? ??.

C21 NR2 P&R 시작(2026-11-06): 기존 C-sim·csynth 보존,15ns 표준 HLS export implementation, 완료 후 setup100경로 및 자원 자동 추출. 실제 배선 결과 대기 중. C20은 csynth까지만 완료.


C21 NR2 P&R ??: WNS ?0.473888ns/WHS +0.036848ns, ???? 15.474ns, 15ns setup ??, ??? 0. LUT 40897/FF 41513/DSP 355/BRAM 0. ?? v2 ?? LUT ?490/FF +425/DSP ?7. ??100?? ??. ?? ??.

### C22 sigmoid 직접 4096항 LUT (2026-11-06)

[C22 실험 기록](../package/results/final_sigmoid_direct4096_csynth/README.md). v2 최종본에서 sigmoid만 현서님 중간점 방식의 4096항 직접 조회로 바꾸고, Q3.13 표를 Q3.12로 반올림해 저장했다. tanh는 기존 256구간 보간을 유지한다. BRAM 없이 조합 조회를 요청했으며 csynth 추정 BRAM은 0이다. Python PA NMSE −45.00 dB, C-sim 7,680개 출력은 Python 후보와 Q12 일치했다.

15 ns / uncertainty 1 ns에서 csynth 완료: LOOP_T II2 / Depth18, 추정 주기 13.889 ns, LUT 238,586 / FF 129,269 / DSP 561 / BRAM_18K 0. v2 최종 HLS 대비 LUT +16,216 / FF +1,289 / DSP +72. LUT 추정치는 기기 가용 230,400을 초과하며, P&R 사용량·타이밍은 아직 확인하지 않았다. 채택 여부 미정, RTL co-sim과 P&R 미실시.

### C23 sigmoid 보간 표 대칭 압축 (2026-11-06)

[C23 실험 기록](../package/results/final_sigmoid_symmetry_csynth/README.md). v2 최종본에서 sigmoid 보간 표만 256항에서 128항으로 압축하고 반대편 구간의 시작값을 대칭으로 복원한다. tanh와 나머지 연산은 유지한다. C++ 함수 입력 32,768개 전수 비교 및 전체 C-sim 출력 7,680개 비교를 통과하면 15ns / uncertainty 1ns / 목표 II2 조건으로 csynth를 진행한다. 진행 상태와 결과는 해당 폴더의 status.txt, csynth.log, csim_comparison.json에서 확인한다. P&R 미실시, 채택 미정.

C23 csynth 완료: C++ sigmoid 32,768개 입력 및 전체 C-sim 7,680개 출력 불일치 0. LOOP_T II2/Depth18, 추정 주기 13.881ns, LUT 212,845 / FF 127,980 / DSP 489 / BRAM_18K 0. 최종 v2 HLS 대비 LUT −9,525 (−4.28%), FF·DSP·BRAM 동일. P&R·RTL co-sim 미실시, 채택 미정.

C23 P&R: 사용자 요청으로 15ns 표준 HLS export implementation 실행. 기존 csynth 보존, 완료 후 setup 경로 100개와 timing summary·utilization 자동 추출. 실제 배치·배선 결과는 아직 확인하지 않았다. RTL co-sim 미실시, 채택 미정.

C23 첫 P&R은 Vivado IP 생성 중 EXCEPTION_ACCESS_VIOLATION으로 종료돼 타이밍 결과가 없다. Tcl store 접근 경고와 충돌의 직접 인과관계는 미확정이다. 실패 로그를 보존하고 동일 csynth/RTL 347파일 SHA256 일치를 확인한 [재시도 01](../package/results/final_sigmoid_symmetry_pnr_retry01/README.md)을 권한 확장해 시작했다. 15ns 조건 유지, csynth 재실행 없음. 결과 미확정.

C23 P&R 재시도 완료: WNS +0.149257ns / WHS +0.036848ns, setup·hold 위반 0, 미배선 0. 비교 주기 14.851ns, 최악 데이터 경로 14.831ns. LUT 40,734 / FF 41,071 / DSP 362 / BRAM 0. v2 최종 대비 LUT −653 (−1.58%), FF −17, DSP·BRAM 동일, WNS +0.056302ns. setup 100경로 추출 완료. RTL co-sim 미실시, 채택 판단 미정.

**2026-11-06 사용자 결정: C23을 [v3.1](v3.1/README.md)로 채택한다.** 위의 '채택 판단 미정'은 결과 확인 당시 기록이다. v2 최종 보관본은 그대로 유지한다. v3.1 RTL co-sim·외부 I/O 통합 타이밍·보드 실측은 미실시다.

### V01 / N1b — C23 RTL의 Vivado 합성 설정

[V01 실험](../package/results/c23_areaoptimized_high_synth/README.md)은 채택 C23의 동일 packaged IP와 15ns 제약으로 HLS IP OOC Vivado 합성 directive만 `sdx_optimization_effort_high`에서 `AreaOptimized_high`로 변경한다. HLS csynth 재실행이나 P&R은 하지 않는다. IP 파일 참조 및 SHA256을 대조했고, Vivado 합성 후 IP·wrapper의 자원과 타이밍 보고서를 생성한다. 실행 상태와 결과는 해당 실험의 synth_status.txt와 synth.log에서 확인한다.

V01 Vivado 합성 정상 완료: IP OOC 및 wrapper 각 synth_design 완료, 종료코드 0. 같은 v3.1 RTL의 기본 합성 대비 LUT 45,013→43,932(−1,081), FF 40,811→40,973(+162), DSP 362 및 BRAM 0 동일. 합성 후 비교 주기 13.693→13.916ns. 배치·배선 결과는 미확인, V01 채택 미정이다.

V01 P&R: 사용자 요청으로 완료된 동일 Vivado 합성 프로젝트를 이어서 15ns route_design까지 실행한다. 합성 설정과 완료 상태 확인 후 setup 100경로·timing summary·utilization·route status를 생성한다. 결과 미확정이다.

V01 P&R 정상 완료: 최종 timing summary 기준 WNS +0.060ns / WHS +0.037ns, setup·hold 위반 및 배선 오류 0. 비교 주기 14.940ns, 최악 데이터 경로 14.921ns. LUT 39,862 / FF 41,168 / DSP 362 / BRAM 0. v3.1 기본 P&R 대비 LUT −872 (−2.14%), FF +97, WNS −0.089ns. setup 100경로 추출 완료. RTL co-sim 미실시, 채택 미정.

2026-11-06 사용자 결정: V01/N1b `AreaOptimized_high`를 현재 v3.1 RTL의 구현 설정으로 채택한다. LUT 수가 3만 개대인 점을 고려했다. 이후 조건 변경으로 타이밍이 맞지 않으면 이 옵션을 제외한 기본 합성 설정과 다시 비교한다. 위 채택 미정은 결정 당시 이전 기록이다.

### P08 — v3.1 recurrent 곱 직후 포화 제거

[소스·결과](../package/results/v31_recurrent_product_nosat_csim/README.md). 제공 7,680개 C-sim 출력은 부모와 Q12 일치. 
2026-11-07 P08 csynth 정상 완료(종료 코드 0). v3.1/C23 대비 HLS LUT 212,845 → 192,560 (−20,285, −9.53%), FF 127,980 / DSP 489 / BRAM 0 동일. LOOP_T II=2, Depth=18, 추정 주기13.881ns(72.04MHz) 동일. II=1 시도 경고 이후 최종 II=2. P&R 미실행이므로 실제 자원·타이밍 효과와 채택 여부는 미확정.

2026-11-07 최종 export/P&R 정상 완료(impl_exit_code=0). ResGRU_export.rpt의 배선 후 LUT 38,047 / FF 40,960 / DSP 362 / BRAM 0. WNS +0.155487ns, WHS +0.036848ns, 미배선 0, Timing met. 비교 주기14.845ns. v3.1 N1b 대비 LUT −1,815(−4.55%), FF −208(−0.51%), DSP/BRAM 동일. 현재 추가 setup 100경로 보고서는 생성 중이며 전체 후처리 완료와 구분한다. P08 채택 미정.

**2026-11-07 사용자 결정: P08을 [v3.2](v3.2/README.md)로 채택한다.** 위 채택 미정은 당시 기록이며 100경로 추출도 완료됐다.
