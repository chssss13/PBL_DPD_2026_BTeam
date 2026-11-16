# Source-only reproduction of the measured HLS/P&R configuration.
# Run from an English path without spaces: vitis_hls -f scripts/implement.tcl
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set SRC [file join $ROOT src_snapshot]
set WORK [file join $ROOT build]
if {[file exists $WORK]} {error "Build directory exists; choose a fresh build directory"}
if {[string first " " $WORK] >= 0} {error "Use a workspace path without spaces"}
file mkdir $WORK
cd $WORK
open_project prj
set_top ResGRU
add_files [file join $SRC multi_gru.cpp] -cflags "-I$SRC -DRESET_ARG"
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false
set_directive_pipeline -II 2 "ResGRU/LOOP_T"
csynth_design
config_export -vivado_synth_design_args {-directive AreaOptimized_high} -vivado_clock 15
export_design -flow impl -format ip_catalog
close_project
exit
