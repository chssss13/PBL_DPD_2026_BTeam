set ROOT [file normalize [file dirname [info script]]]
cd $ROOT
if {[file exists prj]} {error "Project exists"}
open_project prj
set_top ResGRU
set CFLAGS "-I$ROOT/src -DRESET_ARG"
add_files $ROOT/src/multi_gru.cpp -cflags $CFLAGS
add_files -tb $ROOT/tb/tb_resgru.cpp -cflags $CFLAGS
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false
set_directive_pipeline -II 2 "ResGRU/LOOP_T"
csim_design -argv "C:/PBL/PBL_DPD_2026_BTeam/package/golden 7680 $ROOT/hls_out.txt"
puts [exec C:/PBL/venv/Scripts/python.exe $ROOT/verify.py]
set f [open $ROOT/status.txt w]
puts $f "CSIM_MATCHED; CSYNTH_RUNNING"
close $f
csynth_design
set f [open $ROOT/status.txt w]
puts $f "CSYNTH_COMPLETE"
close $f
exit
