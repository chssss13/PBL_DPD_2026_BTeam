source [file join [file dirname [info script]] common.tcl]
cd $WORK
open_project prj
open_solution sol1
cosim_design -rtl verilog -trace_level none \
    -argv [list $GOLDEN 7680 [file join $EROOT rtl_out.txt] 2560]
compare_output rtl
close_project
exit
