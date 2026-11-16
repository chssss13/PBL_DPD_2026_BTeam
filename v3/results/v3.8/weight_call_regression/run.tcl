
open_project {C:/Project/PBL_DPD_2026_BTeam/v3/experiments/v3.8/prj_weight_regression}
open_solution sol1
set_top ResGRU
remove_files {C:/Project/PBL_DPD_2026_BTeam/v3/experiments/v3.8/tb/tb_resgru.cpp}
add_files {C:/Project/PBL_DPD_2026_BTeam/v3/experiments/v3.8/src/multi_gru.cpp} -cflags {-IC:/Project/PBL_DPD_2026_BTeam/v3/experiments/v3.8/src -DRESET_ARG}
add_files -tb {C:/Project/PBL_DPD_2026_BTeam/v3/results/v3.8/weight_call_regression/tb_weight_calls.cpp} -cflags {-IC:/Project/PBL_DPD_2026_BTeam/v3/experiments/v3.8/src -DRESET_ARG}
set rc [catch {
    csim_design -argv {C:/Project/PBL_DPD_2026_BTeam/v3/golden 1536 C:/Project/PBL_DPD_2026_BTeam/v3/results/v3.8/weight_call_regression/c_out.txt 2560}
    cosim_design -rtl verilog -tool xsim -argv {C:/Project/PBL_DPD_2026_BTeam/v3/golden 1536 C:/Project/PBL_DPD_2026_BTeam/v3/results/v3.8/weight_call_regression/rtl_out.txt 2560}
} message options]
remove_files {C:/Project/PBL_DPD_2026_BTeam/v3/results/v3.8/weight_call_regression/tb_weight_calls.cpp}
add_files -tb {C:/Project/PBL_DPD_2026_BTeam/v3/experiments/v3.8/tb/tb_resgru.cpp} -cflags {-IC:/Project/PBL_DPD_2026_BTeam/v3/experiments/v3.8/src -DRESET_ARG}
close_project
if {$rc} { puts $message; exit 1 }
exit
