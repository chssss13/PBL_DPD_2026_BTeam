# Select a bounded subset of shared DATA nets in setup-critical paths.
# Replicate existing combinational/register drivers; do not add pipeline stages.
set candidates [dict create]
set paths [get_timing_paths -quiet -max_paths 200 -nworst 1 -slack_lesser_than 0]
if {![llength $paths]} {set paths [get_timing_paths -quiet -max_paths 200 -nworst 1]}
foreach path $paths {
    # Relationship query returns the datapath nets directly in Vivado 2024.1.
    foreach net [get_nets -quiet -of_objects $path] {
            if {[dict exists $candidates [get_property NAME $net]]} {continue}
            set drivers [get_pins -quiet -leaf -of_objects $net -filter {DIRECTION == OUT}]
            if {[llength $drivers] != 1} {continue}
            set driver [get_cells -quiet -of_objects $drivers]
            set ref [get_property REF_NAME $driver]
            if {![string match LUT* $ref] && ![string match FD* $ref]} {continue}
            set fanout [llength [get_pins -quiet -leaf -of_objects $net -filter {DIRECTION == IN}]]
            if {$fanout >= 16} {dict set candidates [get_property NAME $net] $fanout}
    }
}
set ranked {}
dict for {name fanout} $candidates {lappend ranked [list $fanout $name]}
set ranked [lsort -integer -decreasing -index 0 $ranked]
set selected [lrange $ranked 0 7]
set f [open $OUT/replication_targets.tsv w]
puts $f "fanout\tnet"
set names {}
foreach row $selected {
    lassign $row fanout name
    puts $f "$fanout\t$name"
    lappend names $name
}
close $f
if {![llength $names]} {error "No eligible shared critical data nets; replication not applied"}
report_timing -max_paths 20 -file $OUT/timing_before_replication.rpt
report_utilization -file $OUT/utilization_before_replication.rpt
set before [llength [get_cells -hier -filter {IS_PRIMITIVE == 1}]]
puts "E20: targeted replication on [llength $names] critical shared data nets"
phys_opt_design -force_replication_on_nets [get_nets $names]
set after [llength [get_cells -hier -filter {IS_PRIMITIVE == 1}]]
set f [open $OUT/replication_cell_counts.tsv w]
puts $f "before\tafter\tdelta"
puts $f "$before\t$after\t[expr {$after-$before}]"
close $f
report_utilization -file $OUT/utilization_after_replication.rpt
write_checkpoint -force $OUT/checkpoints/targeted_replication.dcp
