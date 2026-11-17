# 4_3 — 직접 공급 + 수정 FEx 파이프라인 + 입력 가중치 채널 225개 29→14비트 축소

RTL 출처: `V4_1/experiments/v38_fex_pipeline/fixed/direct_narrow/sim/verilog`

각 `rtl/`은 시뮬레이션에 사용한 Verilog 68개이며 `rtl_sha256.json`으로 확인할 수 있습니다. `hls_reference/`는 V3.8 HLS 소스 참조입니다. RTL에서 수행한 변경은 C++ 재합성만으로 재현되지 않습니다. 전체 테스트벤치와 벡터는 이 폴더에 포함되지 않습니다.

`reports/`는 래퍼 포함 배치·배선 보고서입니다. 전체 비교와 검증 범위는 상위 README를 참고하세요.
