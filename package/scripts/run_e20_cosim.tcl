set ROOT [file normalize [file join [file dirname [info script]] ..]]
set OUT $ROOT/results/E20_input_precompute
open_project $ROOT/prj_csim_e20_precompute
open_solution sol1
cosim_design -trace_level none -argv "$ROOT/golden 2624 $OUT/rtl_out.txt 2560"
exit
