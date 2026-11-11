source [file join [file dirname [info script]] common.tcl]
if {[file exists $PROJECT]} {error "Project already exists; refusing overwrite: $PROJECT"}
file mkdir $WORK
cd $WORK
open_project prj
set_top ResGRU
set flags "-I[file join $EROOT src_snapshot] -DRESET_ARG"
add_files [file join $EROOT src_snapshot multi_gru.cpp] -cflags $flags
add_files -tb [file join $EROOT tb_snapshot.cpp] -cflags $flags
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false
set_directive_pipeline -II 2 "ResGRU/LOOP_T"
csim_design -argv [list $GOLDEN 7680 [file join $EROOT csim_out.txt] 2560]
compare_output csim
csynth_design
close_project
exit
