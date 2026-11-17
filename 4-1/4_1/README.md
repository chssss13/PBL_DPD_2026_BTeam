# 4_1 — 기존 V3.8

RTL 출처: `V4_1/analysis/v38_switch_trace/sim/verilog`

각 `rtl/`은 시뮬레이션에 사용한 Verilog 68개이며 `rtl_sha256.json`으로 확인할 수 있습니다. `hls_reference/`는 V3.8 HLS 소스 참조입니다. RTL에서 수행한 변경은 C++ 재합성만으로 재현되지 않습니다. 전체 테스트벤치와 벡터는 이 폴더에 포함되지 않습니다.

`reports/`는 래퍼 포함 배치·배선 보고서입니다. 전체 비교와 검증 범위는 상위 README를 참고하세요.

이 RTL은 V3.8 경계 파형 시뮬레이션용 사본이며 관찰용 alias가 추가되어 있습니다. 기존 V3.8 구현 보고서는 원래 V3.8 결과에서 가져왔습니다.
