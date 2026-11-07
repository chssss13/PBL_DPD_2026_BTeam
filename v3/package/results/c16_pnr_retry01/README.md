# C16 P&R 재시도01

18ns 합성 후보의 동일 HLS 프로젝트를 복사했다. 첫 실행은 IP 생성 단계 Vivado EXCEPTION_ACCESS_VIOLATION으로 종료되었고 배치·배선까지 진행하지 못했다. 스택 정보가 없어 원인 미확정이며 타이밍 실패와 구분한다.
원본 로그·덤프는 보존. 실패한 IP 생성 디렉터리를 재사용하지 않고 새 폴더에서 재생성한다. RTL/data 파일은 SHA256으로 원본과 동일함을 확인했다. 18ns 클록·기존 HLS 설정 유지, 소스 및 합성 결과 변경 없음. 결과는 impl.log 및 timing100 참고.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
