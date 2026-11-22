# New run: C-sim -> Q12 comparison -> optional csynth. Never reset an old project.
source [file join [file dirname [info script]] common.tcl]
set TEAM_MODE csynth
if {[info exists ::env(TEAM_MODE)]} {set TEAM_MODE $::env(TEAM_MODE)}
if {$TEAM_MODE ni {csim csynth}} {error "TEAM_MODE must be csim or csynth"}
if {[file exists $TEAM_RUN]} {error "Run already exists: $TEAM_RUN. Select another TEAM_RUN."}
verify_package
file mkdir $TEAM_RUN
cd $TEAM_RUN
mark_status CSIM_RUNNING
open_project prj
set_top ResGRU
set TEAM_CFLAGS "-I[file join $TEAM_ROOT src] -DRESET_ARG"
add_files [file join $TEAM_ROOT src multi_gru.cpp] -cflags $TEAM_CFLAGS
add_files -tb [file join $TEAM_ROOT tb tb_resgru.cpp] -cflags $TEAM_CFLAGS
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false
set_directive_pipeline -II 2 "ResGRU/LOOP_T"
set TEAM_OUTPUT [file join $TEAM_RUN hls_out.txt]
set TEAM_ARGS [list [file join $TEAM_ROOT golden] 7680 $TEAM_OUTPUT 2560]
csim_design -argv $TEAM_ARGS
puts [exec $TEAM_PYTHON [file join $TEAM_ROOT scripts verify.py] --output $TEAM_OUTPUT --json [file join $TEAM_RUN csim_comparison.json]]
mark_status CSIM_MATCHED
if {$TEAM_MODE eq "csynth"} {
    mark_status CSYNTH_RUNNING
    csynth_design
    mark_status CSYNTH_COMPLETE
}
close_project
exit
