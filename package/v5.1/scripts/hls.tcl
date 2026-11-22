source [file join [file dirname [info script]] common.tcl]
set action $::env(V51_ACTION)
if {$action eq "build"} {
    if {[file exists [file join $WORK prj]]} {error "Refusing existing HLS project"}
    open_project prj
    set_top ResGRU
    set flags "-I$SRC -I[file join $ROOT tb] -DRESET_ARG"
    add_files [file join $SRC multi_gru.cpp] -cflags $flags
    add_files -tb [file join $ROOT tb tb_resgru.cpp] -cflags $flags
    open_solution sol1
    set_part {xczu7ev-ffvc1156-2-e}
    create_clock -period 15 -name default
    set_clock_uncertainty 1.0
    config_schedule -enable_dsp_full_reg=false
    set_directive_pipeline -II 2 "ResGRU/LOOP_T"
    csim_design -argv [list $GOLDEN 7680 [file join $WORK standard_csim.txt] 2560 0]
    csim_design -argv [list $GOLDEN 5120 [file join $WORK stress_csim.txt] 2560 2]
    csynth_design
} elseif {$action eq "cosim_setup"} {
    set tag $::env(V51_TAG)
    if {![regexp {^(control|candidate)_(standard|stress)$} $tag]} {error "Invalid co-sim tag"}
    if {[string match *stress $tag]} {set n 5120;set stimulus 2} else {set n 7680;set stimulus 0}
    open_project prj
    open_solution sol1
    cosim_design -setup -rtl verilog -trace_level none -argv [list $GOLDEN $n [file join $WORK ${tag}_out.txt] 2560 $stimulus]
} else {error "V51_ACTION must be build or cosim_setup"}
close_project
exit
