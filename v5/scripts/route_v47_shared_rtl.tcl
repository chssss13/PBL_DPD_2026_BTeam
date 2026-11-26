# Use the same routed implementation flow for all three v4.7 RTL variants.
if {$argc != 1} {error "Pass a generated RTL directory"}
set rtl [file normalize [lindex $argv 0]]
set out [file join [file dirname $rtl] routed]
if {[file exists $out]} {error "Choose a fresh output directory"}
file mkdir $out
cd $rtl
set_param general.maxThreads 4
read_verilog [glob *.v]
read_xdc ResGRU.xdc
synth_design -top ResGRU -part xczu7ev-ffvc1156-2-e -mode out_of_context -directive AreaOptimized_high
opt_design
place_design
phys_opt_design
route_design
report_utilization -file [file join $out utilization.rpt]
report_utilization -hierarchical -file [file join $out utilization_hierarchical.rpt]
report_timing_summary -file [file join $out timing_summary.rpt]
report_route_status -file [file join $out route_status.rpt]
write_checkpoint [file join $out routed.dcp]
