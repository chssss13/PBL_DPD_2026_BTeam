# Screen the HLS precursor before replaying v4.6 RTL transformations.
set root [file normalize [file join [file dirname [info script]] ..]]
set src [file join $root v4 result v4.2 fullrom_fc21 src]
set fixture [file join $root v4 result v4.1]
set run [file join $root v5 prj_projection_screen]
if {[file exists $run]} {error "Move the previous screening result before rerunning"}
file mkdir $run
cd $run

set input [open [file join $src multi_gru.cpp] r]
set original [read $input]
close $input
set call {Linear<6,H_SIZE,data_t,weight_t,accum_t>(x_w_fex, W_inj, b_inj, x_inj);}
if {[string first $call $original] < 0} {error "Projection call not found"}
set candidate [string map [list $call {SharedProjection(x_w_fex, W_inj, b_inj, x_inj);}] $original]
set after {#include <hls_stream.h>}
set helper {

static void SharedProjection(data_t x[6], weight_t weights[H_SIZE][6],
                             data_t bias[H_SIZE], accum_t output[H_SIZE]) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=2
#pragma HLS ALLOCATION operation instances=mul limit=15
#pragma HLS ARRAY_PARTITION variable=x complete
#pragma HLS ARRAY_PARTITION variable=weights complete dim=0
#pragma HLS ARRAY_PARTITION variable=bias complete
#pragma HLS ARRAY_PARTITION variable=output complete
    for (int row = 0; row < H_SIZE; ++row) {
#pragma HLS UNROLL
        accum_t sum = 0;
        for (int column = 0; column < 6; ++column) {
#pragma HLS UNROLL
            sum += accum_t(x[column] * weights[row][column]);
        }
        output[row] = sum + bias[row];
    }
}
}
set output [open candidate.cpp w]
puts -nonewline $output [string map [list $after "$after\n$helper"] $candidate]
close $output

foreach variant {baseline candidate} {
    open_project $variant
    set_top ResGRU
    set cflags "-I$src -I[file join $fixture src] -DRESET_ARG"
    set design [file join $src multi_gru.cpp]
    if {$variant eq "candidate"} {set design [file join $run candidate.cpp]}
    add_files $design -cflags $cflags
    add_files -tb [file join $fixture tb tb_resgru.cpp] -cflags $cflags
    open_solution sol1
    set_part {xczu7ev-ffvc1156-2-e}
    create_clock -period 15 -name default
    set_clock_uncertainty 1.0
    config_schedule -enable_dsp_full_reg=false
    set_directive_pipeline -II 2 "ResGRU/LOOP_T"
    set args [list [file join $fixture golden] 7680 [file join $run $variant.txt] 2560]
    csim_design -argv $args
    if {$variant eq "candidate"} {
        set baseline_output [open [file join $run baseline.txt] r]
        set candidate_output [open [file join $run candidate.txt] r]
        set matched [expr {[read $baseline_output] eq [read $candidate_output]}]
        close $baseline_output
        close $candidate_output
        if {!$matched} {error "Candidate C-sim output differs"}
        puts "Projection C-sim matched all 7680 samples"
        csynth_design
    }
    close_project
}
exit
