set ROOT [file normalize [file join [file dirname [info script]] ..]]
if {[regexp {[[:space:]]} $ROOT]} {error "Use a path without spaces for Vitis HLS 2024.1"}
set WORK [file join $ROOT build]
set SRC [file join $ROOT src]
set GOLDEN [file join $ROOT golden]
file mkdir $WORK
cd $WORK
