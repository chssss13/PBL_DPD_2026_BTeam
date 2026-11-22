# Continue only a completed synthesis in the selected TEAM_RUN.
source [file join [file dirname [info script]] common.tcl]
verify_package
if {![file exists [file join $TEAM_PROJECT sol1 syn report ResGRU_csynth.rpt]]} {
    error "Completed csynth required. Run reproduce.tcl in csynth mode first."
}
if {![file exists [file join $TEAM_RUN status.txt]]} {error "Missing run status"}
set f [open [file join $TEAM_RUN status.txt] r]
set status [string trim [read $f]]
close $f
if {$status ne "CSYNTH_COMPLETE"} {error "Expected CSYNTH_COMPLETE, found: $status"}
foreach sub {report verilog/project.runs} {
    if {[file exists [file join $TEAM_PROJECT sol1 impl $sub]]} {
        error "Existing implementation found; refusing overwrite. Use a new TEAM_RUN for another attempt."
    }
}
cd $TEAM_RUN
open_project prj
open_solution sol1
mark_status IMPLEMENTATION_RUNNING
export_design -flow impl -format ip_catalog
mark_status IMPLEMENTATION_COMPLETE
close_project
exit
