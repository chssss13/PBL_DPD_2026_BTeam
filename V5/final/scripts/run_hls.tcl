# Default: compile and C-sim only. MODE=csynth also synthesizes; never runs P&R.
set root [file normalize [file join [file dirname [info script]] ..]]
set mode csim
if {[info exists ::env(MODE)]} {set mode $::env(MODE)}
if {$mode ni {csim csynth}} {error "MODE must be csim or csynth"}
set name check01
if {[info exists ::env(RUN_NAME)]} {set name $::env(RUN_NAME)}
if {![regexp {^[A-Za-z0-9_-]+$} $name]} {error "Invalid RUN_NAME"}
set run [file join $root build $name]
if {[file exists $run]} {error "Refusing to overwrite $run; use a new RUN_NAME"}
file mkdir $run
cd $run
open_project prj
set_top ResFastGRNN
set flags "-I$root/src"
add_files [file join $root src res_fastgrnn.cpp] -cflags $flags
add_files -tb [file join $root tb tb_fastgrnn.cpp] -cflags $flags
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false
if {[info exists ::env(TB_ARGS)]} {
    csim_design -argv $::env(TB_ARGS)
} else {
    csim_design
}
if {$mode eq "csynth"} {csynth_design}
close_project
exit
