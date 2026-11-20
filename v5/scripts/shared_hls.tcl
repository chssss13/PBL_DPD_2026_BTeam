set root [file normalize [file join [file dirname [info script]] ../..]]
set run [file join $root v5 prj_shared_$::env(SHARED_SCOPE)]
set fixture [file join $root v4 result v4.1]
set golden [file join $fixture golden]
if {[info exists ::env(SHARED_GOLDEN)]} {set golden [file normalize $::env(SHARED_GOLDEN)]}
cd $run
set project hls
if {[info exists ::env(SHARED_PROJECT)]} {set project $::env(SHARED_PROJECT)}
if {![regexp {^[a-zA-Z0-9_]+$} $project] || [file exists $project]} {error "Choose a fresh project name"}
open_project $project
set_top ResGRU
set cflags "-I[file join $run src] -I[file join $fixture src] -DRESET_ARG"
add_files [file join $run src multi_gru.cpp] -cflags $cflags
add_files -tb [file join $fixture tb tb_resgru.cpp] -cflags $cflags
open_solution sol1
set_part xczu7ev-ffvc1156-2-e
create_clock -period 15 -name default
set_clock_uncertainty 1.0
config_schedule -enable_dsp_full_reg=false
set_directive_pipeline -II 2 "ResGRU/LOOP_T"
csim_design -argv [list $golden 7680 [file join $run ${project}_out.txt] 2560]
if {![info exists ::env(SHARED_CSIM_ONLY)]} {csynth_design}
close_project
exit
