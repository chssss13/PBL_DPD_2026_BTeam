# C08 — DATAFLOW 제거 + r 레이어 공유 분리

부모는 C06 `final_no_top_dataflow_csynth`다. 두 후보는 같은 부모에서 독립적으로 준비했으며 서로의 변경을 포함하지 않는다.

- 변경: Only r recurrent product specializations receive layer-distinct tags; z and n sharing identifiers unchanged.
- `GRU_single<0/1/2>`로 레이어 번호를 전달한다. 원래 레이어 루프와 상태·residual 갱신 순서는 유지한다.
- 수식·자료형·반올림·포화·보간 구간·클록 조건은 C06과 같다. `source.diff`에 부모 대비 변경을 보존한다.
- C-sim 7,680개를 기존 최종본 및 Python Q12와 비교한 뒤 통과할 때만 csynth한다. PA 재평가는 아니다.
- 비교 기준 C06: II3/Depth21, 추정13.999ns, LUT138,995/FF18,500/DSP411/BRAM0.
- 확인할 것: II2 회복 여부, 자원 증가량, 실제 RTL에서 레이어 간 공유 분리가 이루어졌는지. 분리만으로 II2가 보장되지는 않는다.
- P&R·co-sim은 미요청. 실행 상태는 status.txt/csynth.log/exit_code.txt에서 확인한다.

공유용 HLS 상위 보고서: [ResGRU_csynth.rpt](reports/ResGRU_csynth.rpt). 원본 prj 및 중간 생성물은 업로드하지 않는다.
