# v2.5 · 상태 갱신용 z 표현 축소

v2.4에서 상태 갱신용 z를 signed 15/3에서 unsigned 12/0으로 바꿨다. 소수부 12비트는 유지했다.

배선 후 LUT / FF / DSP는 41,781 / 41,175 / 347, 비교 주기는 15.146 ns다.

[변경 설명](../v2.6/changes/코드변경.md#change-14) · [코드 diff](../v2.6/changes/diffs/14_gru_cell.diff) · [전체 결과](../README.md)
