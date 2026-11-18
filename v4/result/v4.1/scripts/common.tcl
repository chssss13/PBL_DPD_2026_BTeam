# Resolve all package paths from this script, independent of the caller's cwd.
set TEAM_ROOT [file normalize [file join [file dirname [info script]] ..]]
if {[regexp {[[:space:]]} $TEAM_ROOT]} {
    error "Vitis HLS 2024.1 does not allow spaces in project paths. Move this folder to a path without spaces."
}
set TEAM_RUN_NAME replay
if {[info exists ::env(TEAM_RUN)]} {set TEAM_RUN_NAME $::env(TEAM_RUN)}
if {![regexp {^[A-Za-z0-9_-]+$} $TEAM_RUN_NAME]} {error "TEAM_RUN must contain only letters, numbers, _ or -"}
set TEAM_RUN [file join $TEAM_ROOT build $TEAM_RUN_NAME]
set TEAM_PROJECT [file join $TEAM_RUN prj]
set TEAM_PYTHON python
if {[info exists ::env(TEAM_PYTHON)]} {set TEAM_PYTHON $::env(TEAM_PYTHON)}
proc verify_package {} {
    global TEAM_PYTHON TEAM_ROOT
    puts [exec $TEAM_PYTHON [file join $TEAM_ROOT scripts verify.py] --package]
}
proc mark_status {message} {
    global TEAM_RUN
    set f [open [file join $TEAM_RUN status.txt] w]
    puts $f $message
    close $f
}
