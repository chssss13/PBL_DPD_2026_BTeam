#pragma once
#include "ap_fixed.h"
#ifdef __SYNTHESIS__
#include <hls_math.h>
#else
#include <cmath>
#endif

#include "linear_layer.h"
#include "config.h"

template<int HIDDEN_SIZE, typename data_T>
void Copy_Bias_PE(
    data_T b_ir[HIDDEN_SIZE], data_T b_hr[HIDDEN_SIZE],
    data_T b_iz[HIDDEN_SIZE], data_T b_hz[HIDDEN_SIZE],
    data_T b_in[HIDDEN_SIZE], data_T b_hn[HIDDEN_SIZE],
    data_T b_ir_local[HIDDEN_SIZE], data_T b_hr_local[HIDDEN_SIZE],
    data_T b_iz_local[HIDDEN_SIZE], data_T b_hz_local[HIDDEN_SIZE],
    data_T b_in_local[HIDDEN_SIZE], data_T b_hn_local[HIDDEN_SIZE]
) {
#pragma HLS INLINE
COPY_BIAS_LOOP:
    for (int i = 0; i < HIDDEN_SIZE; i++) {
#pragma HLS UNROLL
        b_ir_local[i] = b_ir[i];
        b_hr_local[i] = b_hr[i];
        b_iz_local[i] = b_iz[i];
        b_hz_local[i] = b_hz[i];
        b_in_local[i] = b_in[i];
        b_hn_local[i] = b_hn[i];
    }
}
 
template<int IN_SIZE, int HIDDEN_SIZE, typename data_T, typename weight_T, typename accum_T>
void GRU_Kernel_PE(
    data_T x[IN_SIZE], data_T h_prev[HIDDEN_SIZE],
    weight_T W_ir[HIDDEN_SIZE][IN_SIZE], weight_T W_iz[HIDDEN_SIZE][IN_SIZE], weight_T W_in[HIDDEN_SIZE][IN_SIZE],
    weight_T W_hr[HIDDEN_SIZE][HIDDEN_SIZE], weight_T W_hz[HIDDEN_SIZE][HIDDEN_SIZE], weight_T W_hn[HIDDEN_SIZE][HIDDEN_SIZE],
    accum_T W_ir_x[HIDDEN_SIZE], accum_T W_iz_x[HIDDEN_SIZE], accum_T W_in_x[HIDDEN_SIZE],
    accum_T W_hr_h[HIDDEN_SIZE], accum_T W_hz_h[HIDDEN_SIZE], accum_T W_hn_h[HIDDEN_SIZE]
) {
#pragma HLS INLINE
    MVM_PE<IN_SIZE, HIDDEN_SIZE, data_T, weight_T, accum_T>(x, W_ir, W_ir_x);
    MVM_PE<IN_SIZE, HIDDEN_SIZE, data_T, weight_T, accum_T>(x, W_iz, W_iz_x);
    MVM_PE<IN_SIZE, HIDDEN_SIZE, data_T, weight_T, accum_T>(x, W_in, W_in_x);
 
    MVM_PE<HIDDEN_SIZE, HIDDEN_SIZE, data_T, weight_T, accum_T>(h_prev, W_hr, W_hr_h);
    MVM_PE<HIDDEN_SIZE, HIDDEN_SIZE, data_T, weight_T, accum_T>(h_prev, W_hz, W_hz_h);
    MVM_PE<HIDDEN_SIZE, HIDDEN_SIZE, data_T, weight_T, accum_T>(h_prev, W_hn, W_hn_h);
}
 

    struct config_a : nnet::activ_config {
        static const unsigned n_in = 1;
        static const unsigned table_size = 256;
        typedef data_t table_t;
        typedef data_t constant_t;
    };

template<int HIDDEN_SIZE, typename data_T, typename accum_T>
void Gate_Calc_PE(
    accum_T W_ir_x[HIDDEN_SIZE], accum_T W_hr_h[HIDDEN_SIZE], data_T b_ir[HIDDEN_SIZE], data_T b_hr[HIDDEN_SIZE],
    accum_T W_iz_x[HIDDEN_SIZE], accum_T W_hz_h[HIDDEN_SIZE], data_T b_iz[HIDDEN_SIZE], data_T b_hz[HIDDEN_SIZE],
    accum_T W_in_x[HIDDEN_SIZE], accum_T W_hn_h[HIDDEN_SIZE], data_T b_in[HIDDEN_SIZE], data_T b_hn[HIDDEN_SIZE],
    data_T h_prev[HIDDEN_SIZE],
    data_T h_next[HIDDEN_SIZE]
) {
#pragma HLS INLINE
//#pragma HLS DATAFLOW
//#pragma HLS PIPELINE II=1
 
    data_T r_pre, z_pre, r, z, n, one_minus_z, r_h, n_pre;
    data_T b_ir_local[HIDDEN_SIZE], b_hr_local[HIDDEN_SIZE];
    data_T b_iz_local[HIDDEN_SIZE], b_hz_local[HIDDEN_SIZE];
    data_T b_in_local[HIDDEN_SIZE], b_hn_local[HIDDEN_SIZE];
#pragma HLS ARRAY_PARTITION variable=b_ir_local complete dim=1
#pragma HLS ARRAY_PARTITION variable=b_hr_local complete dim=1
#pragma HLS ARRAY_PARTITION variable=b_iz_local complete dim=1
#pragma HLS ARRAY_PARTITION variable=b_hz_local complete dim=1
#pragma HLS ARRAY_PARTITION variable=b_in_local complete dim=1
#pragma HLS ARRAY_PARTITION variable=b_hn_local complete dim=1
 


    Copy_Bias_PE<HIDDEN_SIZE, data_T>(
        b_ir, b_hr,
        b_iz, b_hz,
        b_in, b_hn,
        b_ir_local, b_hr_local,
        b_iz_local, b_hz_local,
        b_in_local, b_hn_local
    );

GATE_LOOP:
    for (int i = 0; i < HIDDEN_SIZE; i++) {
        #pragma HLS UNROLL factor=1
        #pragma HLS PIPELINE II=1
        r_pre = W_ir_x[i] + b_ir_local[i] + W_hr_h[i] + b_hr_local[i];
        nnet::my_hard_sigmoid<data_T,data_T>(r_pre, r);
        //nnet::sigmoid_ele<data_T, data_T, config_a>(r_pre, r);
        r_h = r * (W_hn_h[i] + b_hn_local[i]);
 
        n_pre = W_in_x[i] + b_in_local[i] + r_h;
        nnet::my_hard_tanh<data_T,data_T>(n_pre, n);
        //nnet::tanh_ele<data_T, data_T,config_a>(n_pre, n);
 
        z_pre = W_iz_x[i] + b_iz_local[i] + W_hz_h[i] + b_hz_local[i];
        //nnet::sigmoid_ele<data_T, data_T,config_a>(z_pre, z);
        nnet::my_hard_sigmoid<data_T,data_T>(z_pre, z);
        one_minus_z = (data_T)(1.0) - z;
        h_next[i] = one_minus_z * n + z * h_prev[i];
    }
}
 
template<int IN_SIZE, int HIDDEN_SIZE, typename data_T, typename weight_T, typename accum_T>
void GRU_Cell_PE(
    data_T x[IN_SIZE],
    data_T h_prev[HIDDEN_SIZE],
    data_T h_next[HIDDEN_SIZE],
 
    weight_T W_ir[HIDDEN_SIZE][IN_SIZE], weight_T W_hr[HIDDEN_SIZE][HIDDEN_SIZE],
    weight_T W_iz[HIDDEN_SIZE][IN_SIZE], weight_T W_hz[HIDDEN_SIZE][HIDDEN_SIZE],
    weight_T W_in[HIDDEN_SIZE][IN_SIZE], weight_T W_hn[HIDDEN_SIZE][HIDDEN_SIZE],
    data_T b_ir[HIDDEN_SIZE], data_T b_hr[HIDDEN_SIZE],
    data_T b_iz[HIDDEN_SIZE], data_T b_hz[HIDDEN_SIZE],
    data_T b_in[HIDDEN_SIZE], data_T b_hn[HIDDEN_SIZE]
) {
    #pragma HLS INLINE
    #pragma HLS DATAFLOW
 
    accum_T W_ir_x[HIDDEN_SIZE], W_iz_x[HIDDEN_SIZE], W_in_x[HIDDEN_SIZE];
    accum_T W_hr_h[HIDDEN_SIZE], W_hz_h[HIDDEN_SIZE], W_hn_h[HIDDEN_SIZE];
    #pragma HLS ARRAY_PARTITION variable=W_ir_x complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_iz_x complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_in_x complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hr_h complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hz_h complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hn_h complete dim=1
 
    // GRU MVMs
    GRU_Kernel_PE<IN_SIZE, HIDDEN_SIZE, data_T, weight_T, accum_T>(
        x, h_prev,
        W_ir, W_iz, W_in,
        W_hr, W_hz, W_hn,
        W_ir_x, W_iz_x, W_in_x,
        W_hr_h, W_hz_h, W_hn_h
    );
 
    // Bias copy and gate calculation
    Gate_Calc_PE<HIDDEN_SIZE, data_T, accum_T>(
        W_ir_x, W_hr_h, b_ir, b_hr,
        W_iz_x, W_hz_h, b_iz, b_hz,
        W_in_x, W_hn_h, b_in, b_hn,
        h_prev, h_next
    );
}