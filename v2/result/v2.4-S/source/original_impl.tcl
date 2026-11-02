set ROOT [file normalize [file dirname [info script]]]
cd $ROOT
set project_path [file join $ROOT prj]
if {![file exists "$project_path/sol1/syn/report/ResGRU_csynth.rpt"] || ![file exists "$project_path/sol1/impl/verilog/ResGRU.v"]} {
    error "Completed HLS synthesis and RTL required."
}
if {[file exists "$project_path/sol1/impl/report"] || [file exists "$project_path/sol1/impl/verilog/project.runs"]} {
    error "Implementation already exists; refusing overwrite."
}
open_project $project_path
open_solution sol1
set f [open $ROOT/impl_status.txt w]
puts $f "IMPLEMENTATION_RUNNING"
close $f
export_design -flow impl -format ip_catalog
set f [open $ROOT/impl_status.txt w]
puts $f "IMPLEMENTATION_COMPLETE; check timing reports for pass/fail"
close $f
exit
