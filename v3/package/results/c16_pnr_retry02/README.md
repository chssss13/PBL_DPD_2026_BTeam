# C16 P&R 재시도01

18ns 합성 후보의 동일 HLS 프로젝트를 복사했다. 첫 실행은 IP 생성 단계 Vivado EXCEPTION_ACCESS_VIOLATION으로 종료되었고 배치·배선까지 진행하지 못했다. 스택 정보가 없어 원인 미확정이며 타이밍 실패와 구분한다.
원본 로그·덤프는 보존. 실패한 IP 생성 디렉터리를 재사용하지 않고 새 폴더에서 재생성한다. RTL/data 파일은 SHA256으로 원본과 동일함을 확인했다. 18ns 클록·기존 HLS 설정 유지, 소스 및 합성 결과 변경 없음. 결과는 impl.log 및 timing100 참고.

retry01은 Vivado_init.tcl 사용자 설정 경로 접근 거부로 종료됐다. retry02는 동일 프로젝트를 복사하여 실행 권한 확장으로 재시도한다. 소스·RTL·클록 조건 변경 없음.

## 최종 결과 및 결정
P&R 및100경로 추출 완료. WNS−79.116ns, 비교주기97.116ns, 최악 데이터경로97.097ns. LUT23356/FF7574/DSP502/BRAM0. 사용자 요청으로 현재 DATAFLOW 제거 방향은 미채택·보류하며 C17은 별도다. FEx NR 공유 곱셈기/DSP 레지스터 경계를 추적한 근거는 [경로 분석](path_analysis.md)에 정리했다. 97ns를 GRU tanh 경로나 순수 배선 악화로 설명하지 않는다.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
