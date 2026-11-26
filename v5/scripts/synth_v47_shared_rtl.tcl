# Compare identical out-of-context synthesis settings for the v4.7 variants.
if {$argc != 1} {error "Pass the generated RTL directory"}
set rtl [file normalize [lindex $argv 0]]
set out [file dirname $rtl]
cd $rtl
set_param general.maxThreads 4
read_verilog [glob *.v]
read_xdc ResGRU.xdc
synth_design -top ResGRU -part xczu7ev-ffvc1156-2-e -mode out_of_context -directive AreaOptimized_high
report_utilization -file [file join $out utilization.rpt]
report_utilization -hierarchical -file [file join $out utilization_hierarchical.rpt]
