# v2.4 · n recurrent 곱셈 출력 행별 분리

v2.3의 입력 항별 분리를 유지하고, n 게이트의 recurrent 곱셈을 출력 행별로도 분리했다.

배선 후 LUT / FF / DSP는 41,806 / 41,161 / 347, 비교 주기는 15.266 ns다.

[변경 설명](../v2.6/changes/코드변경.md#change-13) · [코드 diff](../v2.6/changes/diffs/13_gru_cell.diff) · [전체 결과](../README.md)
