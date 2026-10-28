# II=2 scheduling experiment. This script creates a separate HLS project.
# Existing C++ calculations, input data, and the baseline project are unchanged.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set PROJECT [file join $ROOT prj_resgru_ii2]
if {[file exists $PROJECT]} {
    error "Project already exists: $PROJECT. Preserve or rename it before running again."
}
set CFLAGS "-I$ROOT/src -DRESET_ARG"
open_project $PROJECT
set_top ResGRU
add_files $ROOT/src/multi_gru.cpp -cflags $CFLAGS
add_files -tb $ROOT/tb/tb_resgru.cpp -cflags $CFLAGS
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default

# Test these three schedule choices together; verify achieved II in the report.
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false
set_directive_pipeline -II 2 "ResGRU/LOOP_T"

csynth_design
exit
