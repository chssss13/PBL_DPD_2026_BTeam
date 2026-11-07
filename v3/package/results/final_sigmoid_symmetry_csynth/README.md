# C23 sigmoid 보간 표 대칭 압축

부모는 v2 최종본이다. sigmoid 256구간의 양수 구간 128개만 저장하고 음수 구간의 시작값과 기울기를 대칭으로 복원한다. 입력의 구간 내 위치와 반올림은 유지한다. tanh 및 다른 연산은 그대로다. 15ns / uncertainty 1ns / 목표 II2 / DSP full reg false.

C++ 테스트벤치에서 원래 표와 32,768개 입력을 전수 비교하고, 전체 C-sim 출력 7,680개를 v2 최종 C-sim과 Q12 비교한다. 두 검증이 통과해야 csynth가 실행된다. P&R과 RTL co-sim은 미실시, 채택 미정이다. 진행 상황과 결과는 status.txt, csim_comparison.json, csynth.log에서 확인한다.

## csynth 결과

C++ sigmoid 전체 입력 32,768개, 전체 모델 출력 7,680개 비교 모두 불일치 0이다. csynth는 정상 완료했고 LOOP_T II2 / Depth18, 추정 주기 13.881ns이다.

| HLS 추정 자원 | v2 최종 | C23 | 변화 |
|---|---:|---:|---:|
| LUT | 222,370 | 212,845 | −9,525 (−4.28%) |
| FF | 127,980 | 127,980 | 0 |
| DSP | 489 | 489 | 0 |
| BRAM_18K | 0 | 0 | 0 |

sigmoid 함수 하나의 HLS LUT 추정치는 1,457→822, 635개 감소했다. 상위 보고서에서 15개 인스턴스의 추정 감소량 15×635=9,525가 전체 추정 감소량과 같다. 실제 배치·배선 후 절감량과 15ns 타이밍은 별도 확인이 필요하다. P&R·RTL co-sim은 미실시다.

## P&R 실행 (2026-11-06)

사용자 요청으로 이 후보의 csynth RTL에 15ns 표준 HLS export implementation을 실행한다. 기존 csynth·C-sim 결과는 보존하고 완료 후 setup 경로 100개와 timing summary·utilization을 자동 추출한다. 실행 결과는 impl.log, impl_status.txt, timing100에서 확인한다. 타이밍과 자원 결과는 아직 확인하지 않았다. RTL co-sim은 미실시다.

첫 실행은 Vivado IP 생성 단계에서 `EXCEPTION_ACCESS_VIOLATION`으로 종료됐고 배치·배선 결과는 없다. 로그에 Tcl store 접근 경고가 있으나 충돌의 직접 원인은 미확정이다. 동일한 csynth·RTL과 15ns 조건을 검증해 복사한 [재시도 01](../final_sigmoid_symmetry_pnr_retry01/README.md)을 사용자 설정 경로에 접근 가능한 권한으로 실행했다. 실행 시작만 확인했으며 결과는 재시도 로그에서 확인한다.

재시도 01 완료: IP 내부 15ns 조건에서 WNS +0.149257ns, WHS +0.036848ns, setup/hold 위반 0, 미배선 0. 비교 주기 14.851ns. P&R LUT 40,734 / FF 41,071 / DSP 362 / BRAM 0으로 v2 최종 대비 LUT −653 / FF −17이다. setup 100경로 및 타이밍·자원 보고서를 추출했다. RTL co-sim 미실시, 채택 미정.

2026-11-06 사용자 결정: C23을 **v3.1**로 채택한다. 위의 채택 미정은 결과 확인 당시 상태이며, RTL co-sim은 별도로 남아 있다.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
