
#pragma once
#include "ap_fixed.h"
#include "hls_stream.h"
#include "gru_cell.h"



void GRU_Layer(
    hls::stream<data_t> &in_stream,
    hls::stream<data_t> &out_stream,
    bool reset,
    data_t h_state[H_SIZE],
    weight_t W_ir[H_SIZE][I_SIZE], weight_t W_hr[H_SIZE][H_SIZE],
    weight_t W_iz[H_SIZE][I_SIZE], weight_t W_hz[H_SIZE][H_SIZE],
    weight_t W_in[H_SIZE][I_SIZE], weight_t W_hn[H_SIZE][H_SIZE],
    data_t b_ir[H_SIZE], data_t b_hr[H_SIZE],
    data_t b_iz[H_SIZE], data_t b_hz[H_SIZE],
    data_t b_in[H_SIZE], data_t b_hn[H_SIZE]
);

void MultiLayerGRU(
    hls::stream<data_t> &x_in,
    hls::stream<data_t> &y_out,
    bool reset,
    weight_t W_ir[NUM_LAYERS][H_SIZE][I_SIZE],
    weight_t W_hr[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_iz[NUM_LAYERS][H_SIZE][I_SIZE],
    weight_t W_hz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_in[NUM_LAYERS][H_SIZE][I_SIZE],
    weight_t W_hn[NUM_LAYERS][H_SIZE][H_SIZE],
    data_t b_ir[NUM_LAYERS][H_SIZE], data_t b_hr[NUM_LAYERS][H_SIZE],
    data_t b_iz[NUM_LAYERS][H_SIZE], data_t b_hz[NUM_LAYERS][H_SIZE],
    data_t b_in[NUM_LAYERS][H_SIZE], data_t b_hn[NUM_LAYERS][H_SIZE]
);
void ResGRU(
    data_t IQ_seq[TIME_STEP][2],
    data_t OUT_seq[TIME_STEP][2],

    weight_t W_inj[H_SIZE][6],
    data_t b_inj[H_SIZE],
    weight_t prelu_param,
    weight_t gating_params[NUM_LAYERS],

    weight_t W_ir[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hr[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_iz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_in[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hn[NUM_LAYERS][H_SIZE][H_SIZE],
    data_t b_ir[NUM_LAYERS][H_SIZE], data_t b_hr[NUM_LAYERS][H_SIZE],
    data_t b_iz[NUM_LAYERS][H_SIZE], data_t b_hz[NUM_LAYERS][H_SIZE],
    data_t b_in[NUM_LAYERS][H_SIZE], data_t b_hn[NUM_LAYERS][H_SIZE],

    weight_t W_out[2][H_SIZE],
    data_t b_out[2]
);