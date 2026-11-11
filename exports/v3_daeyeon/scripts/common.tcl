set EROOT [file normalize [file join [file dirname [info script]] ..]]
if {![info exists ::env(E24_WORK_DIR)] || ![info exists ::env(PBL_PYTHON)]} {
    error "Run through python run.py or launch_background.py so Python/build paths are configured"
}
set WORK [file normalize $::env(E24_WORK_DIR)]
set PROJECT [file join $WORK prj]
set PYTHON $::env(PBL_PYTHON)
set GOLDEN [file join $EROOT golden]
proc compare_output {name} {
    global EROOT PYTHON
    puts [exec $PYTHON [file join $EROOT scripts verify.py] --output [file join $EROOT ${name}_out.txt] --json [file join $EROOT reports ${name}_comparison.json]]
}
