set root [file normalize [file join [file dirname [info script]] ..]]
set rtl [file join $root final_rtl]
set out [file join $root wrapper_pnr]
if {[file exists $out]} {error "Refusing to overwrite $out"}
file mkdir $out
cd $out
set part xczu7ev-ffvc1156-2-e
set_param general.maxThreads 4
create_project package_project [file join $out package_project] -part $part
add_files -norecurse [glob -directory $rtl ResFastGRNN*.v]
add_files -norecurse [glob -directory $rtl *.dat]
set_property top ResFastGRNN [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir [file join $out ip] -vendor xilinx.com -library hls -taxonomy /UserIP -import_files -force
set core [ipx::current_core]
set_property name ResFastGRNN $core
set_property version 1.0 $core
ipx::save_core $core
close_project
create_project project [file join $out project] -part $part
set_property ip_repo_paths [file join $out ip] [current_project]
update_ip_catalog
create_bd_design bd_0
set inst [create_bd_cell -type ip -vlnv xilinx.com:hls:ResFastGRNN:1.0 hls_inst]
make_bd_pins_external $inst
make_bd_intf_pins_external $inst
foreach p [get_bd_intf_ports] {set_property name [regsub {_0$} [get_property name $p] {}] $p}
foreach p [get_bd_ports -filter {INTF!=TRUE}] {set_property name [regsub {_0$} [get_property name $p] {}] $p}
validate_bd_design
save_bd_design
set bd [get_files */bd_0.bd]
generate_target all $bd
set wrapper [make_wrapper -files $bd -top]
add_files -norecurse $wrapper
set_property top bd_0_wrapper [current_fileset]
set xdc [file join $out clock.xdc]
set fh [open $xdc w]; puts $fh {create_clock -name ap_clk -period 15.000 [get_ports ap_clk]}; close $fh
add_files -fileset constrs_1 $xdc
launch_runs synth_1 -scripts_only
foreach run [get_runs -filter {IS_SYNTHESIS == 1}] {reset_run $run}
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
set ip_inst [get_ips -quiet bd_0*hls_inst*]
set ip_run [get_runs -filter {IS_SYNTHESIS == 1} ${ip_inst}*]
if {![llength $ip_run]} {error "Cannot find IP synthesis run"}
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-directive AreaOptimized_high} -objects $ip_run
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
launch_runs impl_1 -to_step route_design -jobs 4
puts "ROUTE_STARTED"
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]} {error "Routed design has black boxes"}
report_utilization -file [file join $out utilization_routed.rpt]
report_timing_summary -file [file join $out timing_routed.rpt]
report_route_status -file [file join $out route_status.rpt]
report_timing -max_paths 10 -file [file join $out timing_paths_routed.rpt]
write_checkpoint [file join $out routed.dcp]
puts "WRAPPER_P_AND_R_COMPLETE"
close_project
exit
