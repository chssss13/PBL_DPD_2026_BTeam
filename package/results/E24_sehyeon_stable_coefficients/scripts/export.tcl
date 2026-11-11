source [file join [file dirname [info script]] common.tcl]
cd $WORK
open_project prj
open_solution sol1
export_design -flow syn -format ip_catalog
close_project
exit
