set SRCROOT [file normalize [file dirname [info script]]]
set REPO [file normalize "$SRCROOT/../../../.."]
set PROJECT "$REPO/v2/package/prj_replay_v24s"
if {[file exists $PROJECT]} {error "Replay project exists; refusing overwrite: $PROJECT"}
if {![file isdirectory "$REPO/package/golden"]} {error "Missing package/golden"}
open_project $PROJECT
set_top ResGRU
set CFLAGS "-I$SRCROOT/src -DRESET_ARG"
add_files "$SRCROOT/src/multi_gru.cpp" -cflags $CFLAGS
add_files -tb "$SRCROOT/tb/tb_resgru.cpp" -cflags $CFLAGS
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false
set_directive_pipeline -II 2 "ResGRU/LOOP_T"
set output "$PROJECT/replay_hls_out.txt"
csim_design -argv "$REPO/package/golden 7680 $output"
puts [exec python "$SRCROOT/verify_replay.py" "$SRCROOT/../accuracy/hls_out.txt" $output]
csynth_design
if {[info exists ::env(V24S_IMPL)] && $::env(V24S_IMPL) eq "1"} {
    export_design -flow impl -format ip_catalog
}
exit
