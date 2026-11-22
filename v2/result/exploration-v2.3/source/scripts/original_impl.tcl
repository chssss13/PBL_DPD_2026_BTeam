# Implement existing combined narrow candidate RTL. Do not reset or rerun HLS synthesis.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set project_path [file join $ROOT prj_combined_narrow_synth]
if {![file exists "$project_path/sol1/syn/report/ResGRU_csynth.rpt"]} {
    error "HLS synthesis report not found."
}
if {![file exists "$project_path/sol1/impl/verilog/ResGRU.v"]} {
    error "Generated Verilog not found."
}
if {[file exists "$project_path/sol1/impl/report"] || [file exists "$project_path/sol1/impl/verilog/project.runs"]} {
    error "An implementation run already exists; preserve it before rerunning."
}
open_project $project_path
open_solution sol1
export_design -flow impl -format ip_catalog
exit
