# Implement the co-simulation-verified RTL without resetting the HLS project.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set PROJECT [file join $ROOT prj_resgru_comb_ii2]
if {![file exists [file join $PROJECT sol1 syn verilog ResGRU.v]]} {
    error "Synthesized RTL was not found: $PROJECT"
}
if {[file exists [file join $PROJECT sol1 impl report]]} {
    error "Implementation report directory already exists. Preserve it before retrying."
}
open_project $PROJECT
open_solution sol1
export_design -flow impl -format ip_catalog
exit
