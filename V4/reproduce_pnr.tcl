set root [file normalize [file dirname [info script]]]
set out [file join $root build pnr]
if {[file exists $out]} {error "Output already exists: $out"}
file mkdir $out
set part xczu7ev-ffvc1156-2-e
create_project -in_memory -part $part
read_verilog [glob -directory [file join $root rtl] ResGRU*.v]
read_xdc [file join $root clock.xdc]
synth_design -top ResGRU -part $part -mode out_of_context -flatten_hierarchy rebuilt -directive AreaOptimized_high
report_utilization -file [file join $out utilization_synth.rpt]
report_timing_summary -file [file join $out timing_synth.rpt]
opt_design
place_design
phys_opt_design
route_design
report_utilization -file [file join $out utilization_routed.rpt]
report_timing_summary -file [file join $out timing_routed.rpt]
report_route_status -file [file join $out route_status.rpt]
report_timing -max_paths 10 -file [file join $out timing_paths_routed.rpt]
write_checkpoint -force [file join $out routed.dcp]
close_project
exit
