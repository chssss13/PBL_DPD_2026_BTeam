# Read-only inspection of the accepted v3.6 placed/routed netlist.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
open_checkpoint $ROOT/experiments/v3.6/prj_candidate/sol1/impl/verilog/project.runs/impl_1/bd_0_wrapper_routed.dcp
set counts [dict create]
set cells [get_cells -hier -filter {REF_NAME =~ FD* && NAME =~ *Block_entry_split_proc_U0/*}]
foreach c $cells {
    set name [file tail $c]
    regsub {\[[0-9]+\]$} $name {} stem
    dict incr counts $stem
}
set rows {}
dict for {stem count} $counts {lappend rows [list $count $stem]}
set output [open $ROOT/results/batch/entry_ff_profile.tsv w]
puts $output "FF_count\tregister_stem"
foreach row [lsort -integer -decreasing -index 0 $rows] {
    puts $output "[lindex $row 0]\t[lindex $row 1]"
}
close $output
puts "ENTRY_FF_PROFILE total=[llength $cells] stems=[dict size $counts]"
close_design
exit
