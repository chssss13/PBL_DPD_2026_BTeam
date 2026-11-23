# Reproduce the saved 7,680-sample trained-parameter C simulation.
set root [file normalize [file join [file dirname [info script]] ..]]
set name trained_check01
if {[info exists ::env(RUN_NAME)]} {set name $::env(RUN_NAME)}
if {![regexp {^[A-Za-z0-9_-]+$} $name]} {error "Invalid RUN_NAME"}
set ::env(RUN_NAME) $name
set ::env(MODE) csim
set ::env(TB_ARGS) [list [file join $root golden parameters.txt] [file join $root golden test_input.txt] 7680 [file join $root build $name trained_hls_out.txt] 2560]
source [file join $root scripts run_hls.tcl]
