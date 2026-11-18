set ROOT [file normalize [file dirname [info script]]]
cd $ROOT
open_project prj
open_solution sol1
cosim_design -rtl verilog -tool xsim -trace_level none -argv [list {C:/PBL/PBL_DPD_2026_BTeam/v4/result/v4.1/golden} 7680 "$ROOT/cosim_out.txt" 2560]
exit