# Implement the checkpoint synthesized from the co-sim RTL.
if {$argc != 1 || [lindex $argv 0] ni {layer2 all}} {error "Pass layer2 or all"}
set scope [lindex $argv 0]
set root [file normalize [file join [file dirname [info script]] ..]]
set project [file join $root prj_shared_$scope]
set out [file join $project vivado_direct_routed]
if {[file exists [file join $out routed.dcp]]} {error "Routed result already exists"}
file mkdir $out
set_param general.maxThreads 4
open_checkpoint [file join $project vivado_direct_utilization synthesized.dcp]
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -file [file join $out timing_summary.rpt]
report_utilization -file [file join $out utilization.rpt]
report_utilization -hierarchical -file [file join $out utilization_hierarchical.rpt]
report_route_status -file [file join $out route_status.rpt]
write_checkpoint [file join $out routed.dcp]
