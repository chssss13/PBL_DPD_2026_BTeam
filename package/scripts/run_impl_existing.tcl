# Run implementation using the existing C synthesis results.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $ROOT prj_resgru]
open_solution sol1
export_design -flow impl -format ip_catalog
exit
