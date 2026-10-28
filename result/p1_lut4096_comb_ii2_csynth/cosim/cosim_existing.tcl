# Use the already synthesized design; do not reset the project or solution.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set PROJECT [file join $ROOT prj_resgru_comb_ii2]
set OUT [file join $ROOT results rtl_cosim_7680.txt]
if {![file exists [file join $PROJECT sol1 syn verilog ResGRU.v]]} { error "Synthesized RTL not found" }
if {[file exists $OUT]} { error "Output already exists: $OUT" }
open_project $PROJECT
open_solution sol1
cosim_design -rtl verilog -tool xsim -argv "$ROOT/golden 7680 $OUT 2560"
exit
