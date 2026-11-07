set ROOT [file normalize [file dirname [info script]]]
cd $ROOT
if {[file exists prj]} {error "Project exists; refusing reset"}
proc stage {text} {
    global ROOT
    set f [open $ROOT/status.txt w]
    puts $f $text
    close $f
    puts "EXPERIMENT_STAGE: $text"
}
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
# C-sim inherited from identical source and testbench; see validation_provenance.json.
stage CSYNTH_RUNNING
csynth_design
stage CSYNTH_COMPLETE
exit
