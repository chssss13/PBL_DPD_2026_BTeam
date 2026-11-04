set ROOT [file normalize [file join [file dirname [info script]] ..]]
set OUT $ROOT/results/checkpoint_audit
file mkdir $OUT
open_checkpoint $ROOT/artifacts/checkpoints/ResGRU_routed.dcp
report_timing_summary -file $OUT/timing_summary.rpt
report_route_status -file $OUT/route_status.rpt
report_utilization -file $OUT/utilization.rpt
set f [open $OUT/slack.txt w]
puts $f "Clock periods: [get_property PERIOD [get_clocks]]"
puts $f "Setup slack: [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]"
puts $f "Hold slack: [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]"
close $f
exit
