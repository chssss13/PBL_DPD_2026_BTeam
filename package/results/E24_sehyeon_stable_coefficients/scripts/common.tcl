set EROOT [file normalize [file join [file dirname [info script]] ..]]
set REPO [file normalize [file join $EROOT .. .. ..]]
set WORK [file join $REPO runs e24]
set PROJECT [file join $WORK prj]
set PYTHON [file join $REPO package .venv Scripts python.exe]
set GOLDEN [file join $REPO runs sehyeon_final golden]

proc compare_output {name} {
    global EROOT PYTHON
    puts [exec $PYTHON [file join $EROOT scripts verify.py] \
        --output [file join $EROOT ${name}_out.txt] \
        --json [file join $EROOT reports ${name}_comparison.json]]
}
