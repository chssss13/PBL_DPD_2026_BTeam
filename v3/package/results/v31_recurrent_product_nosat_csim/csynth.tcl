set ROOT [file normalize [file dirname [info script]]]
cd $ROOT
open_project prj
open_solution sol1
create_clock -period 15 -name default
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false
set_directive_pipeline -II 2 "ResGRU/LOOP_T"
set f [open csynth_status.txt w]; puts $f CSYNTH_RUNNING; close $f
csynth_design
set f [open csynth_status.txt w]; puts $f CSYNTH_COMPLETE; close $f
exit
