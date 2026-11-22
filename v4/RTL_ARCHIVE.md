# v4.3~v4.6 RTL 보관본

제공받은 `v4.3-v4.6_RTL.zip`의 각 버전을 아래 경로에 원본 바이트 그대로 보관한다. Verilog, XSim 헤더, FEx ROM 초기화 데이터, 15 ns 클록 제약을 포함한다.

| 버전 | RTL 경로 | 파일 수 |
|---|---|---:|
| v4.3 | [final_rtl](result/v4.3/final_rtl/) | 64 |
| v4.4 | [final_rtl](result/v4.4/final_rtl/) | 67 |
| v4.5 | [final_rtl](result/v4.5/final_rtl/) | 64 |
| v4.6 | [final_rtl](result/v4.6/final_rtl/) | 64 |

v4.5와 v4.6의 RTL에서 `rtl_changes.json`에 기록된 75개 피연산자 연결을 모두 대조했다. v4.5는 기록된 전달 레지스터를 사용하며, v4.6은 각 FIFO 출력에 연결된 직접 전달 포트를 사용한다. ROM 초기화 파일의 참조도 확인했다. [v4.6 변경 기록](result/v4.6/reports/rtl_changes.json)

원본 ZIP SHA-256은 `6a78f159af3fce8b45915e07f12d7d1add86e8cde9a4a65ac41d88c1110fea5d`다.

Vivado 2024.1의 `xvlog` 및 `xelab`로 네 버전의 `ResGRU` 컴파일과 elaboration을 확인했다. 기존 co-sim과 배치·배선 보고서는 당시 실행 결과다.

세현 브랜치에서 가져온 채택 최종본 v4.7의 [최종 RTL](result/v4.7/final_rtl/)과 [검증·배선 후 보고서](result/v4.7/README.md)를 함께 보관한다.
