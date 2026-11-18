# Run with Vivado 2024.1 after implement.tcl has completed.
source [file join [file dirname [info script]] common.tcl]
set checkpoints [glob -nocomplain -directory [file join $TEAM_PROJECT sol1 impl verilog project.runs impl_1] *_routed.dcp]
if {[llength $checkpoints] != 1} {error "Expected exactly one routed checkpoint: $checkpoints"}
set TEAM_OUT [file join $TEAM_RUN timing100]
if {[file exists $TEAM_OUT]} {error "Report directory already exists: $TEAM_OUT"}
file mkdir $TEAM_OUT
open_checkpoint [lindex $checkpoints 0]
report_timing -delay_type max -max_paths 100 -nworst 1 -path_type full_clock_expanded -file [file join $TEAM_OUT setup_paths100.rpt]
report_timing_summary -file [file join $TEAM_OUT timing_summary.rpt]
report_utilization -file [file join $TEAM_OUT utilization.rpt]
report_route_status -file [file join $TEAM_OUT route_status.rpt]
close_design
mark_status REPORTS_COMPLETE
exit
