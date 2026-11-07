set ROOT [file normalize [file dirname [info script]]]
cd $ROOT
if {![file exists prj/sol1/sol1.aps]} {error "C-sim project missing"}
if {[file exists prj/sol1/syn/report/ResGRU_csynth.rpt]} {error "Existing synthesis result; refusing overwrite"}
open_project prj
open_solution sol1
set_directive_pipeline -II 2 "ResGRU_TimeLoop/LOOP_T"
set f [open csynth_status.txt w]
puts $f CSYNTH_RUNNING
close $f
if {[catch {csynth_design} message]} {
    puts stderr $message
    exit 1
}
if {![file exists prj/sol1/syn/report/ResGRU_csynth.rpt]} {exit 1}
set f [open csynth_status.txt w]
puts $f CSYNTH_COMPLETE
close $f
exit 0
