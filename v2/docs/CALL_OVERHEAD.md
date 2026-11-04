# 호출 오버헤드 개선 재개

최종 상태: v2.3/v2.4는 폐기했고 개별 프로젝트·결과 폴더도 현재 없다.
식 변형 v3.1도15ns 실패로 폐기했다. 현재 채택본은v2.2이며 호출 오버헤드는 판정에서 제외한다.
버전별 기록은 [v2.3](v2.3_start_propagation_discarded.md), [v2.4](v2.4_ctrl_chain_discarded.md)를 참고한다.
아래는 당시 실행·검토 이력이다.

현재 상태: 사용자 지시에 따라 이 작업은 중단한다. 처리율은 기존 v0 기준인
클록/II로 평가하며 호출 오버헤드를 합격 조건으로 사용하지 않는다.
진행 중인 새 v2.5의 식 변형 결과까지만 보고한다. 아래는 과거 실험 이력이다.

사용자 요청에 따라 이전 보류를 해제한다. 15 ns와 정확도, II≤2, 16비트 조건은 유지한다.
기존 PLAN의 타이밍 통과 시 중단 규칙은 v2.1~v2.2 단계에 한정한다.

## 기존 결과 정정 및 확인

과거 v2.5와 새 v2.2는 같은 실측 성능이다. 둘 다 post-route 14.885 ns,
WNS +0.115 ns, WHS +0.019 ns, II2이다.
두 co-simulation 보고서 모두 64샘플 호출 간격 134cycle, 전체7680샘플16113cycle이다.
15 ns에서 호출 간격 기준31.8408 MSps, 전체 테스트 기준31.7756 MSps이므로
호출 오버헤드 포함33.3 MSps 통과 이력으로 해석하면 안 된다.

목표 호출 간격은 floor(64/(33.3*0.015))=128cycle 이하이다.
호출 간격의 min/avg/max 중 보수적으로 max를 사용한다.
최초 pipeline fill 및 최종 drain을 포함한 전체 테스트 처리율도 별도로 기록하고,
그 값이 미달이면 전체 테스트 처리율까지 통과했다고 주장하지 않는다.
입력/출력 전송·호스트 소프트웨어 시간은 기존 테스트벤치가 측정하지 않는다.

## 폐기한 호출 제어 실험

v2.3/v2.4는 사용자 요청으로 폐기했다. 둘 다 II2, 호출 간격134cycle,
RTL 지연167cycle, HLS 추정주기13.789ns이며 HLS 추정 자원도 v2.2와 같았다.
배치배선은 생략했다. 재실행 목록에서 제외했으며 개별 프로젝트/결과는 현재 삭제된 상태다.
후속 식 변형은 [v3.1 상세](../../v3/docs/v3.1_hidden_state.md)에 기록했다.

| 후보 | 기반 | 변경 | 검증할 가설 |
|---|---|---|---|
| v2.3 | v2.2 | top DATAFLOW disable_start_propagation | 내부 start 토큰 전달 대기 제거 |
| v2.4 | v2.2 | top ap_ctrl_chain | 완료/다음 호출 제어의 중첩 개선 |

두 후보를 섞지 않고 각각 기준과 비교한다. 입력·출력·reset 간격·블록64는 유지한다.
호출 중첩 시 reset과 가중치의 호출별 의미가 보존되는지는 전체 C/RTL 비교로 검증한다.
C 검증 → 합성 II → 전체 cosim 및 PA → 실제 호출 처리율 판정 순이다.
33.3 MSps 미달 후보는 RTL 결과를 보존하고 배치배선을 생략한다.
처리율 통과 후보만 동일15 ns로 배치배선하고 routed setup/hold를 판정한다.
합성 추정 interval만으로 성공 판정하지 않는다.
둘 다 실패하면 새 후보를 무작정 추가하지 않고 제어 RTL을 분석해 v2.5를 설계한다.

이전 `run_overhead_flow.py` 실행은 비활성화했다. 위 후보를 다시 예약하지 않는다.

근거: [AMD 2024.1 start propagation FIFO 설명](https://docs.amd.com/r/2024.1-English/ug1399-vitis-hls/Specifying-Compiler-Created-FIFO-Depth),
[AMD ap_ctrl_chain 예제](https://xilinx.github.io/Vitis_Accel_Examples/2021.1/html/kernel_chain.html).
문서는 적용 가능성의 근거이며 본 회로의 성능 개선을 보장하지 않는다.
