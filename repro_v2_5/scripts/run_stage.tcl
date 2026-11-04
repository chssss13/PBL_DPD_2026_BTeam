set ROOT [file normalize [file join [file dirname [info script]] ..]]
set OUT $::env(RUN_OUT)
set PROJECT $::env(RUN_PROJECT)
set ACTION $::env(RUN_ACTION)
if {$ACTION eq "csim"} {
    open_project -reset $PROJECT
    set_top ResGRU
    set FLAGS "-I$OUT/src -DRESET_ARG -DFEX_INTERNAL_FIXED=1 -DFEX_INV_I=8 -DACT_LUT=2 -DDIRECT_LUT_SHIFT=4 -DV2_ROM=1 -DV2_ACT_REG=0 -DV2_GATE=0 -DV2_TREE=$::env(RUN_TREE)"
    add_files $OUT/src/multi_gru.cpp -cflags $FLAGS
    add_files -tb $OUT/tb_resgru.cpp -cflags $FLAGS
    open_solution -reset sol1
    set_part {xczu7ev-ffvc1156-2-e}
    create_clock -period 15 -name default
    set_clock_uncertainty 1.0
    config_schedule -enable_dsp_full_reg=false
    set_directive_pipeline -II 2 "ResGRU/LOOP_T"
    csim_design -argv "$ROOT/golden 7680 $OUT/hls_out.txt"
} else {
    open_project $PROJECT
    open_solution sol1
    if {$ACTION eq "csynth"} {csynth_design}
    if {$ACTION eq "cosim"} {cosim_design -rtl verilog -tool xsim -argv "$ROOT/golden 7680 $OUT/rtl_out.txt"}
    if {$ACTION eq "impl"} {export_design -flow impl -format ip_catalog}
}
exit
