# Implement the preserved v1.5 (old E07) RTL without re-running synthesis.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $ROOT prj_e07]
open_solution sol1
export_design -flow impl -format ip_catalog
exit
