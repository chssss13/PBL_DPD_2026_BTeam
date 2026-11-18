# v4.3 — FIFO 채널 제어 공유

[v4.2](../v4.2/README.md)의 파라미터 FIFO 566개와 채널별 깊이 2를 유지했다. 같은 조건에서 읽고 쓰는 채널은 최대 32개씩 묶어, 저장 상태와 읽기·쓰기 가능 여부를 그룹 단위로 관리했다. 공유 제어기는 18개다.

동일한 기본 합성 옵션의 P&R에서 FIFO 제어부는 **3,396→130 FF(−96.2%)**, 전체 FF는 **41,015→37,331**이었다. LUT는 **36,810→31,934**, WNS는 **+0.319787 ns**다. FIFO 저장부의 실제 FF도 16,052→15,902로 달라졌다. [블록별 FF 비교](../../README.md#블록별-ff-변화).

Verilog/XSim co-sim에서 7,680샘플을 통과했다. 출력 파일은 부모 참조와 바이트 단위로 일치했다. 호출 지연은 144클록, 호출 간격은 134클록이다.

[P&R 자원](reports/utilization.rpt) · [타이밍](reports/timing_summary.rpt) · [RTL co-sim](reports/ResGRU_cosim.rpt) · [출력 대조](reports/output_identity.json) · [RTL 변경 기록](reports/rtl_changes.json)
