set ROOT [file normalize [file dirname [info script]]]
cd $ROOT
open_project prj
set_top ResGRU
add_files "$ROOT/src/multi_gru.cpp" -cflags "-I$ROOT/src -DRESET_ARG"
add_files -tb "$ROOT/tb/tb_resgru.cpp" -cflags "-I$ROOT/src -DRESET_ARG"
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false

set_directive_pipeline -II 2 "ResGRU/LOOP_T"
csim_design -argv [list {C:/PBL/PBL_DPD_2026_BTeam/v4/result/v4.1/golden} 7680 "$ROOT/hls_out.txt" 2560]
exit


