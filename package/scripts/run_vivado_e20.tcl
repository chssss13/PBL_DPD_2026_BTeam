# Same OOC wrapper, part, 15ns constraint, and backend options as E13.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set WORK $ROOT/prj_csim_e20_precompute/sol1/impl/verilog
set REPORT $WORK/report
file mkdir $REPORT
set_param general.maxThreads 2
create_project project $WORK -part xczu7ev-ffvc1156-2-e
set_property target_language Verilog [current_project]
set_property ip_repo_paths $ROOT/prj_csim_e20_precompute/sol1/impl/ip [current_project]
update_ip_catalog
create_bd_design bd_0
set cell [create_bd_cell -type ip -vlnv xilinx.com:hls:ResGRU:1.0 hls_inst]
make_bd_pins_external $cell
make_bd_intf_pins_external $cell
set_property CONFIG.FREQ_HZ 66000000 [get_bd_ports -filter {TYPE==clk}]
foreach port [get_bd_intf_ports] {set_property name [regsub {_0$} [get_property name $port] {}] $port}
foreach port [get_bd_ports -filter {INTF!=TRUE}] {set_property name [regsub {_0$} [get_property name $port] {}] $port}
assign_bd_address
save_bd_design
set wrapper [make_wrapper -files [get_files bd_0.bd] -top]
add_files -norecurse $wrapper
set_property top bd_0_wrapper [current_fileset]
set xdc $WORK/ResGRU_e20.xdc
set f [open $xdc w]
puts $f {create_clock -period 15.000 -name ap_clk [get_ports ap_clk]}
close $f
add_files -fileset constrs_1 $xdc
add_files -fileset utils_1 -norecurse $ROOT/scripts/vivado_impl_pre.tcl
launch_runs synth_1 -scripts_only
foreach run [get_runs -filter {IS_SYNTHESIS == 1}] {
    reset_run $run
    set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none $run
    set_property STEPS.SYNTH_DESIGN.ARGS.RESOURCE_SHARING off $run
    set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE Default $run
    set_property STEPS.SYNTH_DESIGN.TCL.PRE $ROOT/scripts/vivado_impl_pre.tcl $run
    if {$run eq "synth_1"} {
        set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects $run
    }
}
set_property XPM_LIBRARIES {XPM_MEMORY XPM_FIFO} [current_project]
launch_runs synth_1 -jobs 1
wait_on_run synth_1
if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} {error "Vivado synthesis failed"}

open_run synth_1
if {![llength [get_clocks -quiet ap_clk]]} {read_xdc $xdc}
if {[llength [get_cells -hier -quiet -filter {IS_BLACKBOX == 1}]]} {error "Unresolved IP black boxes"}
set OUT $ROOT/results/E20_input_precompute
file mkdir $OUT/checkpoints
write_checkpoint -force $OUT/checkpoints/linked_synth.dcp
close_project
open_checkpoint $OUT/checkpoints/linked_synth.dcp
if {![llength [get_clocks -quiet ap_clk]]} {read_xdc $xdc}
if {abs([get_property PERIOD [get_clocks ap_clk]]-15)>0.0001} {error "Clock changed"}
opt_design -directive Explore
place_design -directive Explore
write_checkpoint -force $OUT/checkpoints/placed.dcp
source $ROOT/scripts/e20_targeted_replication.tcl
phys_opt_design -directive AggressiveExplore
route_design -directive Explore

proc save_results {stage} {
    global OUT
    set REPORT $OUT/$stage/impl/verilog/report
    file mkdir $REPORT
    report_utilization -file $REPORT/ResGRU_utilization_routed.rpt
    report_timing_summary -file $REPORT/ResGRU_timing_routed.rpt
    report_timing -max_paths 20 -file $REPORT/ResGRU_timing_paths_routed.rpt
    report_route_status -file $REPORT/ResGRU_status_routed.rpt
    report_drc -file $REPORT/ResGRU_drc_routed.rpt
    report_methodology -file $REPORT/ResGRU_methodology_routed.rpt
    write_checkpoint -force $OUT/checkpoints/$stage.dcp
}
save_results route
phys_opt_design -directive Explore
set rs [report_route_status -return_string]
if {[regexp {# of unrouted nets[^:]*:\s*([0-9]+)} $rs -> count] && $count>0} {
    route_design -directive Explore
}
save_results postroute
close_design
exit
