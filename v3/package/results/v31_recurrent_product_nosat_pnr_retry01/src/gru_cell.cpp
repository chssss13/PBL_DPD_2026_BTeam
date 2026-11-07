#include "ap_fixed.h"
#include "gru_cell.h"

#define IN_SIZE 4
#define HIDDEN_SIZE 4


void GRU(
    data_t x[IN_SIZE],
    bool reset,
    data_t h_out[HIDDEN_SIZE],

    // New weight matrices (split into input and hidden)
    weight_t W_ir[HIDDEN_SIZE][IN_SIZE], weight_t W_hr[HIDDEN_SIZE][HIDDEN_SIZE],
    weight_t W_iz[HIDDEN_SIZE][IN_SIZE], weight_t W_hz[HIDDEN_SIZE][HIDDEN_SIZE],
    weight_t W_in[HIDDEN_SIZE][IN_SIZE], weight_t W_hn[HIDDEN_SIZE][HIDDEN_SIZE],

    // New biases (split)
    data_t b_ir[HIDDEN_SIZE], data_t b_hr[HIDDEN_SIZE],
    data_t b_iz[HIDDEN_SIZE], data_t b_hz[HIDDEN_SIZE],
    data_t b_in[HIDDEN_SIZE], data_t b_hn[HIDDEN_SIZE]
) {
#pragma HLS INLINE off
#pragma HLS DATAFLOW

    static data_t h_state[HIDDEN_SIZE];
#pragma HLS ARRAY_PARTITION variable=h_state complete dim=1

    // Reset state if needed
RESET_LOOP:
    for (int i = 0; i < HIDDEN_SIZE; i++) {
#pragma HLS UNROLL
        if (reset)
            h_state[i] = 0;
    }

    data_t h_next[HIDDEN_SIZE];
#pragma HLS ARRAY_PARTITION variable=h_next complete dim=1

    // Call new GRU cell
    GRU_Cell_PE<IN_SIZE, HIDDEN_SIZE, data_t, weight_t, accum_t>(
        x, h_state, h_next,
        W_ir, W_hr,
        W_iz, W_hz,
        W_in, W_hn,
        b_ir, b_hr,
        b_iz, b_hz,
        b_in, b_hn
    );

UPDATE_LOOP:
    for (int i = 0; i < HIDDEN_SIZE; i++) {
#pragma HLS UNROLL
        h_state[i] = h_next[i];
        h_out[i] = h_next[i];
    }
}
