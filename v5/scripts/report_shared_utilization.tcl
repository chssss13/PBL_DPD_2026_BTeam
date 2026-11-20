# Vivado out-of-context synthesis of the HLS-generated RTL.
if {$argc < 1 || $argc > 2 || [lindex $argv 0] ni {layer2 all} || ($argc == 2 && [lindex $argv 1] ne "direct")} {
    error "Pass layer2 or all, optionally followed by direct"
}
set scope [lindex $argv 0]
set root [file normalize [file join [file dirname [info script]] ..]]
set rtl [file join $root prj_shared_$scope hls sol1 syn verilog]
set out [file join $root prj_shared_$scope vivado_utilization]
if {$argc == 2} {
    set rtl [file join $root prj_shared_$scope hls sol1 sim verilog]
    set out [file join $root prj_shared_$scope vivado_direct_utilization]
    set fd [open [file join $rtl .. report ResGRU_cosim.rpt] r]
    set report [read $fd]
    close $fd
    if {![regexp {Verilog\s*\|\s*Pass} $report]} {error "Direct RTL co-sim has not passed"}
}
file mkdir $out
cd $rtl
set_param general.maxThreads 4
read_verilog [glob *.v]
set constraint [file join $out clock.xdc]
set fd [open $constraint w]
puts $fd {create_clock -name ap_clk -period 15.000 [get_ports ap_clk]}
close $fd
read_xdc $constraint
synth_design -top ResGRU -part xczu7ev-ffvc1156-2-e -mode out_of_context -directive AreaOptimized_high
report_utilization -file [file join $out utilization.rpt]
report_utilization -hierarchical -file [file join $out utilization_hierarchical.rpt]
report_timing_summary -file [file join $out timing_summary.rpt]
write_checkpoint -force [file join $out synthesized.dcp]
