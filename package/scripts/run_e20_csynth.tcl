set ROOT [file normalize [file join [file dirname [info script]] ..]]
open_project $ROOT/prj_csim_e20_precompute
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default
set_clock_uncertainty 4.05
csynth_design
exit
