# Run C/RTL verification on an already synthesized solution. No resynthesis/P&R.
set root [file normalize [file join [file dirname [info script]] ..]]
set name synth01
if {[info exists ::env(RUN_NAME)]} {set name $::env(RUN_NAME)}
if {![regexp {^[A-Za-z0-9_-]+$} $name]} {error "Invalid RUN_NAME"}
set run [file join $root build $name]
if {![file exists [file join $run prj sol1 syn report ResFastGRNN_csynth.xml]]} {
    error "Synthesis is not complete: $run"
}
cd $run
open_project prj
open_solution sol1
set args [list [file join $root tb fixtures parameters.txt] [file join $root tb fixtures input.txt] 128 [file join $run loaded_out.txt] 128]
csim_design -argv $args
cosim_design -rtl verilog -tool xsim -trace_level none -argv $args
close_project
exit
