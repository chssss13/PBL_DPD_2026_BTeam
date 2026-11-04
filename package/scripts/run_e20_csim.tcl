set ROOT [file normalize [file join [file dirname [info script]] ..]]
set OUT $ROOT/results/E20_input_precompute
set SNAP $OUT/src_snapshot
open_project $ROOT/prj_csim_e20_precompute
set_top ResGRU
add_files $SNAP/multi_gru.cpp -cflags "-I$SNAP"
add_files -tb $OUT/tb_snapshot.cpp -cflags "-I$SNAP"
open_solution sol1
set_part {xczu7ev-ffvc1156-2-e}
csim_design -argv "$ROOT/golden 7680 $OUT/precomputed.txt 2560"
exit
