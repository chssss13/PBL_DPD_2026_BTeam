# Resume v1.6 without resetting its completed synthesis.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
open_project prj_e08
open_solution sol1
set NT [expr {[info exists ::env(NT)] ? $::env(NT) : 7680}]
cosim_design -rtl verilog -tool xsim -argv "$ROOT/golden $NT $ROOT/results/v1.6_schedule/rtl_out.txt"
exit
