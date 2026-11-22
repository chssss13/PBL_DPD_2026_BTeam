# Reproduce archived v2.1; refuses to overwrite an existing replay project.
set SOURCE [file normalize [file dirname [info script]]]
set PACKAGE [file normalize [file join $SOURCE .. .. .. package]]
set PROJECT [file join $PACKAGE prj_replay_v2_1]
set STEPS [expr {[info exists ::env(STEPS)] ? $::env(STEPS) : "csim"}]
if {[file exists $PROJECT]} { error "Replay project exists; preserve it before another run." }
set CFLAGS "-I$SOURCE/src -DRESET_ARG -DACT_LUT=2 -DDIRECT_LUT_SHIFT=4 -DFEX_INTERNAL_FIXED=1 -DFEX_INV_I=8"
open_project $PROJECT
set_top ResGRU
add_files $SOURCE/src/multi_gru.cpp -cflags $CFLAGS
add_files -tb $SOURCE/tb/tb_resgru.cpp -cflags $CFLAGS
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false
set_directive_pipeline -II 2 "ResGRU/LOOP_T"
set OUTDIR [file join $PACKAGE results replay_v2_1]
file mkdir $OUTDIR
set ARGV "[file join $PACKAGE golden] 7680 [file join $OUTDIR hls_out.txt]"
if {[lsearch $STEPS csim] >= 0} { csim_design -argv $ARGV }
if {[lsearch $STEPS csynth] >= 0} { csynth_design }
if {[lsearch $STEPS cosim] >= 0} { cosim_design -argv $ARGV }
if {[lsearch $STEPS impl] >= 0} { export_design -flow impl -format ip_catalog }
exit
