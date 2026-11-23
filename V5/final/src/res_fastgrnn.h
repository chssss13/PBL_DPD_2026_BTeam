#pragma once
#include "config.h"

// 237 scalar parameters. No legacy reset/update/candidate matrix or bias ports.
// Arrays are row-major [layer][output][input]. Parameters remain stable per call.
void ResFastGRNN(
    data_t IQ_seq[TIME_STEP][2], data_t OUT_seq[TIME_STEP][2],
    weight_t W_inj[H_SIZE][6], data_t b_inj[H_SIZE],
    weight_t prelu_param, weight_t gating_params[NUM_LAYERS],
    weight_t W[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t U[NUM_LAYERS][H_SIZE][H_SIZE],
    data_t b_z[NUM_LAYERS][H_SIZE], data_t b_h[NUM_LAYERS][H_SIZE],
    weight_t zeta[NUM_LAYERS], weight_t nu[NUM_LAYERS],
    weight_t W_out[2][H_SIZE], data_t b_out[2], bool segment_start);
