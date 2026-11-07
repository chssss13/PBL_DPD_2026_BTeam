# C06 후속 — 시간 루프와 상태의 함수 경계 변경 (C-sim만)

## 후속 실행 승인: C10 csynth

C-sim 통과 후 사용자가 csynth 실행을 요청했다. 같은 소스와 프로젝트를 초기화 없이 열어 `csynth.tcl`로 합성한다. 기존 C-sim 로그·결과는 보존한다. 디렉터리명의 `_csim`은 준비 당시 이름이며 변경하지 않는다. 합성 상태는 `csynth_status.txt`, 결과는 `csynth.log`, `csynth_exit_code.txt`, `prj/sol1/syn/report/`에서 확인한다. P&R은 실행하지 않는다. C06 대비 II2 회복·자원·상태 forwarding 생성 여부를 평가한다.

C06에서 독립 분기. C07/C08의 연산기 분리는 포함하지 않는다.
원래 ResGRU 본문 전체를 static non-inline `ResGRU_TimeLoop`로 옮겼다. static hidden state와 LOOP_T가 이 함수 안에 함께 있고, 최상위 ResGRU는 모든 인수를 전달한다.
포트 ARRAY_PARTITION 지시문은 최상위에도 유지한다. 수식·비트폭·레이어 순서·reset 조건·상태 유지 방식의 C++ 의미는 같다.
Tcl II2 지시 대상은 이동한 루프 ResGRU_TimeLoop/LOOP_T로 맞췄다.

이번 사용자 승인 범위는 C-sim만이다. run.tcl에는 csynth_design 명령이 없다.
기존 테스트벤치 7680개, segment 길이2560을 사용하여 기존 최종본 C-sim 및 Python Q12와 비교한다. PA 재평가와 전체 입력 동등성 증명은 아니다.
II2 회복·bypass 생성 여부는 C-sim으로 알 수 없으며 추후 csynth/RTL 확인이 필요하다.

## C-sim 결과

정상 완료(exit0). 7,680개 출력이 기존 최종 C-sim과 최대 오차0으로 일치했고 Python 참조와 Q12 불일치0이다. `csim_comparison.json`과 `csim.log`에 결과를 보존한다. csynth는 실행하지 않았다.

## 후속 csynth 완료 결과

2026-11-05 23:43 정상 완료, csynth_exit_code=0, 합성 소요14분55초. 위 C-sim만 실행했다는 문장은 당시 상태다.

| 항목 | 부모 C06 | C10 |
|---|---:|---:|
| LOOP_T II / Depth | 3 / 21 | 3 / 21 |
| 추정 주기 ns | 13.999 | 13.999 |
| LUT | 138995 | 138865 |
| FF | 18500 | 18095 |
| DSP / BRAM | 411 / 0 | 411 / 0 |
| top latency / interval 클록 | 216 / 217 | 219 / 220 |

LUT−130, FF−405이나 II2 회복은 실패했다. 함수 경계 변경만으로 처리율 제약을 해결하지 못했으며 top 호출 간격은3클록 증가했다. 경고는 tanh와 r recurrent 누산 사이 II2 carried dependence다. bypass의 유무가 단독 원인이라는 가설은 입증되지 않았다. P&R·co-sim 미실시, 사용자 채택 결정 전. 개선 후보 검토는 진행할 수 있지만 새 실험 실행은 별도 요청을 따른다.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
