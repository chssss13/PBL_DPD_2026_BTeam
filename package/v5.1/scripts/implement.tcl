source [file join [file dirname [info script]] common.tcl]
set variant candidate
if {[info exists ::env(V51_VARIANT)]} {set variant $::env(V51_VARIANT)}
if {$variant ni {control candidate}} {error "V51_VARIANT must be control or candidate"}
set BUILD [file join $WORK impl_$variant]
set OUT [file join $WORK reports $variant]
set CHECKPOINTS [file join $WORK checkpoints]
set RTL [file join $BUILD rtl]
if {[file exists $BUILD]} {error "Refusing existing implementation directory"}
file mkdir $RTL
file mkdir $OUT
file mkdir $CHECKPOINTS
if {$variant eq "control"} {set SOURCE [file join $ROOT baseline_rtl]} else {set SOURCE [file join $ROOT rtl]}
foreach f [glob -directory $SOURCE *] {
    if {[file extension $f] in {.v .vh .dat}} {file copy $f [file join $RTL [file tail $f]]}
}
create_project v51_$variant [file join $BUILD project] -part xczu7ev-ffvc1156-2-e
cd $RTL
set_property include_dirs [list $RTL] [current_fileset]
read_verilog [glob -directory $RTL *.v]
set xdc [file join $BUILD clock.xdc]
set f [open $xdc w]
puts $f {create_clock -name ap_clk -period 15.000 [get_ports ap_clk]}
close $f
read_xdc $xdc
set_property top ResGRU [current_fileset]
update_compile_order -fileset sources_1
synth_design -top ResGRU -part xczu7ev-ffvc1156-2-e -mode out_of_context -directive AreaOptimized_high
write_checkpoint [file join $BUILD synthesized.dcp]
opt_design -directive Explore
place_design -directive Explore
phys_opt_design -directive AggressiveExplore
route_design -directive Explore
write_checkpoint [file join $CHECKPOINTS ${variant}_initial_route.dcp]
report_timing_summary -file [file join $OUT initial_timing_summary.rpt]
phys_opt_design -directive AggressiveExplore
route_design -directive Explore
write_checkpoint [file join $CHECKPOINTS ${variant}_routed.dcp]
report_utilization -file [file join $OUT utilization.rpt]
report_utilization -hierarchical -file [file join $OUT utilization_hierarchical.rpt]
report_timing_summary -report_unconstrained -file [file join $OUT timing_summary.rpt]
report_timing -delay_type max -max_paths 100 -path_type full_clock_expanded -file [file join $OUT setup_paths100.rpt]
report_route_status -file [file join $OUT route_status.rpt]
report_drc -file [file join $OUT drc.rpt]
report_clocks -file [file join $OUT clocks.rpt]
check_timing -verbose -file [file join $OUT check_timing.rpt]
set worst [get_timing_paths -delay_type max -max_paths 1]
if {[llength $worst]!=1} {error "Missing constrained timing path"}
set f [open [file join $OUT metrics.json] w]
puts $f [format {{"WNS_ns":%.9f,"clocks":[{"name":"ap_clk","period_ns":15.0}]}} [get_property SLACK $worst]]
close $f
close_project
exit
