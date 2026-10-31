# Isolated architecture candidate. Same part/clock and default scheduling as v0.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set CASE state_logic
if {[info exists ::env(ARCH_CASE)]} { set CASE $::env(ARCH_CASE) }
set DIR [file join $ROOT results default_schedule $CASE]
set FLAGS "-I$DIR/src -DRESET_ARG -DACT_LUT=2 -DDIRECT_LUT_SHIFT=2 -DFEX_INTERNAL_FIXED=1 -DFEX_INV_I=8"
open_project -reset prj_default_$CASE
set_top ResGRU
add_files $DIR/src/multi_gru.cpp -cflags $FLAGS
add_files -tb $DIR/tb_resgru.cpp -cflags $FLAGS
open_solution -reset sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default
# Deliberately no config_schedule, set_clock_uncertainty or pipeline override.
csim_design -argv "$ROOT/golden 7680 $DIR/hls_out.txt"
csynth_design
exit
