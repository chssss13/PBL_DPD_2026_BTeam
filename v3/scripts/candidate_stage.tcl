set ROOT [file normalize [file join [file dirname [info script]] ..]]
set BASE $ROOT
set CASE $::env(EXPERIMENT_CASE)
set ACTION $::env(EXPERIMENT_STAGE)
set OUT $::env(EXPERIMENT_OUT)
set PROJECT $CASE/prj_candidate
file mkdir $OUT/$ACTION
if {$ACTION eq "csim"} {
    open_project -reset $PROJECT
    set_top ResGRU
    set FLAGS "-I$CASE/src -DRESET_ARG"
    add_files $CASE/src/multi_gru.cpp -cflags $FLAGS
    add_files -tb $CASE/tb/tb_resgru.cpp -cflags $FLAGS
    open_solution -reset sol1
    set_part {xczu7ev-ffvc1156-2-e}
    create_clock -period 15 -name default
    set_clock_uncertainty 1.0
    config_schedule -enable_dsp_full_reg=false
    if {[file exists $CASE/candidate_directives.tcl]} {
        source $CASE/candidate_directives.tcl
    }
    set_directive_pipeline -II 2 "ResGRU/LOOP_T"
    csim_design -argv [list $BASE/golden 7680 $OUT/csim/hls_out.txt 2560]
} else {
    open_project $PROJECT
    open_solution sol1
    if {$ACTION eq "csynth"} {csynth_design}
    if {$ACTION eq "cosim"} {
        cosim_design -rtl verilog -tool xsim -argv [list $BASE/golden 7680 $OUT/cosim/rtl_out.txt 2560]
    }
    if {$ACTION eq "impl"} {
        export_design -flow impl -format ip_catalog
    }
}
close_project
exit
