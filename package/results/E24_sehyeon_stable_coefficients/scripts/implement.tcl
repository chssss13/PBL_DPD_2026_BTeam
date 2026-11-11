source [file join [file dirname [info script]] common.tcl]
set_param general.maxThreads 2
set project_files [glob -nocomplain -directory [file join $PROJECT sol1 impl verilog] *.xpr]
if {[llength $project_files] != 1} {error "Expected one generated project: $project_files"}
open_project [lindex $project_files 0]
if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} {
    error "RTL synthesis incomplete"
}
set impl [get_runs impl_1]
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore $impl
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore $impl
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true $impl
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore $impl
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore $impl
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED false $impl
launch_runs impl_1 -to_step route_design -jobs 1
wait_on_run impl_1
if {![string match "*Complete*" [get_property STATUS $impl]] ||
    [get_property PROGRESS $impl] ne "100%"} {error "Implementation failed"}
open_run impl_1

proc save_reports {stage} {
    global EROOT
    set out [file join $EROOT reports $stage]
    file mkdir $out
    report_timing_summary -file [file join $out timing_summary.rpt]
    report_timing -delay_type max -max_paths 20 -nworst 1 -path_type full_clock_expanded \
        -file [file join $out critical_paths.rpt]
    report_utilization -file [file join $out utilization.rpt]
    report_route_status -file [file join $out route_status.rpt]
    report_drc -file [file join $out drc.rpt]
    write_checkpoint [file join $EROOT checkpoints ${stage}.dcp]
}
save_reports route
close_project

open_checkpoint [file join $EROOT checkpoints route.dcp]
phys_opt_design -directive AggressiveExplore
set route_status [report_route_status -return_string]
set reroute 0
if {[regexp {# of nets with routing errors[^:]*:\s*([0-9]+)} $route_status -> n] && $n > 0} {set reroute 1}
if {[regexp {# of routable nets[^:]*:\s*([0-9]+)} $route_status -> total] &&
    [regexp {# of fully routed nets[^:]*:\s*([0-9]+)} $route_status -> done] && $total != $done} {set reroute 1}
if {$reroute} {route_design -directive Explore}
save_reports postroute
close_design
exit
