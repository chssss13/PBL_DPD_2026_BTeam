# E24: 고정 계수 전달·DATAFLOW 버퍼 중복 감소

2026-11-08. 우선순위 2번 실험이다. 기준은 sehyeon 최종본 `43bbc198f25ec5bd7473a063c510a819efbf400a`의 재실행 결과이며, 미채택한 E23 변경은 포함하지 않는다.

`src_snapshot/multi_gru.cpp`의 ResGRU 최상위 DATAFLOW에 가중치·bias·PReLU·gating 계수 인자 18개에 대한 STABLE 지정을 추가했다. 계수의 중복 전달·동기화·버퍼를 줄일 수 있는지 평가한다. 모든 계수값, 수치 형식, LUT·NR4, 산술식, 리셋 정책은 기준본과 같다. 전체 DATAFLOW 삭제나 FIFO 깊이의 일괄 축소는 적용하지 않는다.

**적용 조건:** 진행 중인 모든 호출이 완료될 때까지 계수값을 변경하지 않는다. 현재 테스트벤치는 계수를 한 번 로드하고 유지하므로 이 조건을 만족한다. 실행 중 계수 갱신을 허용해야 하는 시스템에는 이 가정을 그대로 적용할 수 없다. IQ 입력·출력·segment_start·은닉 상태에는 STABLE을 지정하지 않는다.

기준 P&R: II=2, WNS +0.049ns, STA 환산 주기 14.951ns, LUT 41,388 / FF 41,088 / DSP 362.

실행 순서:

1. C-sim 7,680샘플과 현재 참조 Q12 코드 비교.
2. HLS 합성과 실제 LOOP_T II=2 확인.
3. Verilog RTL co-sim 7,680샘플·Q12 코드 비교. `trace_level none`으로 파형 추적을 비활성화한다.
4. Vivado 합성·Explore opt/place/route·AggressiveExplore 물리 최적화.
5. 배선 후 AggressiveExplore와 최종 결과 수집.

도구는 Vitis HLS·Vivado 2024.1, FPGA xczu7ev-ffvc1156-2-e, 목표 15ns, HLS uncertainty 1ns, DSP full register false다. 빌드 위치는 `runs/e24`이며 소스 변경은 `source_changes.diff`에 있다.

`run.py`를 분리된 백그라운드 프로세스로 한 번 실행한다. 실행 상태 조회·폴링·진행 상태 파일·대기 세션·별도 watcher는 만들지 않는다. C-sim 단계부터 채팅을 점유하지 않는다. 도구 자체 로그는 오류 확인을 위해 `logs/`에만 보관한다.

완료 또는 실패 시에만 이 폴더의 `RESULTS.md`와 `evaluation.json`을 생성한다. 성공 시 실제 P&R 보고서는 `reports/`, checkpoint는 `checkpoints/`에 저장한다. 기존 기준본을 자동 교체하지 않는다.

원본의 단계 간 FIFO 전달 방식, STABLE로 의도한 변경, 실제로 확인된 효과의 차이는 [최종 보고서의 동작 비교](RESULTS.md#원본-동작과-e24가-의도한-변경)에 정리했다. 독립 실행용 배포본은 저장소 루트의 `exports/v3_daeyeon`이다.

GitHub includes sources and the explanatory report only. The full Desktop v3_daeyeon distribution contains the local validation data and native reports.
