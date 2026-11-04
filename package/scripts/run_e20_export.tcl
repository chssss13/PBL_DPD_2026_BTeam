set ROOT [file normalize [file join [file dirname [info script]] ..]]
open_project $ROOT/prj_csim_e20_precompute
open_solution sol1
export_design -format ip_catalog
exit
