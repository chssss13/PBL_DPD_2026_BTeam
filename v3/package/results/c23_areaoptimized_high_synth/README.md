# V01 / N1b: C23 RTL의 Vivado 면적 중심 합성

현재 채택 기준 v3.1(C23)의 packaged IP와 15ns 제약을 사용한다. IP 내 RTL과 component.xml 참조 파일의 SHA256 일치와 전체 참조 존재를 확인했다. HLS IP OOC Vivado 합성 directive를 `sdx_optimization_effort_high`에서 `AreaOptimized_high`로만 변경한다. HLS csynth 재실행 없이 Vivado 합성까지만 수행하며 P&R은 미실시다.

원본 C23 합성 후 보고서와 같은 종류의 IP OOC·wrapper 합성 보고서를 비교해야 한다. 경로·설정은 settings.diff, 진행 상태는 synth_status.txt 및 synth.log를 확인한다. 합성 추정 결과는 실제 배치·배선 자원과 타이밍이 아니다.

## Vivado 합성 결과

IP OOC 및 wrapper synth_design 모두 정상 완료(진행률 100%, 종료코드 0). `AreaOptimized_high`가 IP OOC 합성 명령에 적용됐다. 로그의 `# puts stderr "ERROR: $message"`는 실패를 처리하는 Tcl 코드가 표시된 것이며 실제 오류 발생 메시지가 아니다. OOC 타이밍의 HD.CLK_SRC 경고가 있어 합성 후 추정은 실제 배선 타이밍과 구분한다.

| Vivado 합성 후 | v3.1 기본 설정 | V01 면적 중심 | 변화 |
|---|---:|---:|---:|
| LUT | 45,013 | 43,932 | −1,081 (−2.40%) |
| FF | 40,811 | 40,973 | +162 |
| DSP | 362 | 362 | 0 |
| BRAM | 0 | 0 | 0 |
| 비교 주기(합성 후) | 13.693ns | 13.916ns | +0.223ns |

동일 C23 RTL과 15ns 조건의 Vivado 합성 단계끼리 비교했다. V01의 P&R·최종 배선 타이밍은 미확인이고, v3.1 기본 설정 P&R 결과와 직접 자원 비교하지 않는다. RTL co-sim 미실시, V01 채택 여부 미정이다.

## P&R 실행 (2026-11-06)

사용자 요청으로 위 Vivado 합성 프로젝트와 완료된 checkpoint를 이어서 15ns 조건으로 배치·배선한다. 합성 프로젝트의 완료 상태 및 IP `AreaOptimized_high` 설정을 확인하고 `route_design`까지 실행한 뒤 routed checkpoint, setup 경로 100개, timing summary, utilization 및 route status를 보관한다. 기존 합성 결과는 보존한다. 실행 상태 및 결과는 impl_status.txt, impl.log, timing100을 확인한다.

## P&R 결과

route_design 및 100경로 보고서 생성 정상 완료. IP 내부 15ns 조건의 최종 timing summary는 WNS +0.060ns / WHS +0.037ns, setup·hold 위반 0, 배선 오류 0이다. 비교 주기는 14.940ns이며 데이터 경로 지연은 14.921ns다. 중간 router 추정 WNS +0.040ns는 최종 timing summary와 구분한다.

| P&R 결과 | v3.1 기본 설정 | V01 면적 중심 합성 | 변화 |
|---|---:|---:|---:|
| LUT | 40,734 | 39,862 | −872 (−2.14%) |
| FF | 41,071 | 41,168 | +97 |
| DSP / BRAM | 362 / 0 | 362 / 0 | 동일 |
| WNS | +0.149ns | +0.060ns | −0.089ns |
| 비교 주기 | 14.851ns | 14.940ns | +0.089ns |

동일 RTL의 15ns P&R 결과이며 V01은 LUT가 감소했지만 setup 여유가 줄었다. IP 내부 경로 기준이며 외부 I/O 통합 타이밍과 RTL co-sim은 미실시다. V01 채택 여부는 사용자가 결정한다. P&R은 완료된 Vivado 합성 프로젝트에서 직접 시작했으므로 HLS export_design의 최종 요약 로그는 출력되지 않는다.

2026-11-06 사용자 결정: N1b를 현재 v3.1 RTL의 Vivado 구현 설정으로 채택한다. LUT 수가 4만 개 미만으로 줄어든 점을 고려했다. 향후 코드나 조건이 바뀌어 타이밍이 맞지 않으면 기본 합성 설정을 다시 비교한다. 위 채택 미정은 결정 전의 상태다.
