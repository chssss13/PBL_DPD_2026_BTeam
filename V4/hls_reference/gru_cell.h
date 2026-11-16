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
 
// Distinct non-inlined multiplier specializations for r/z/n recurrent paths.
// Preserve full product precision and request combinational (zero-cycle) calls.
template<int GATE, int TERM, typename data_T, typename weight_T>
ap_fixed<data_T::width + weight_T::width, data_T::iwidth + weight_T::iwidth>
Recurrent_Term_Product(data_T x, weight_T w) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1
#pragma HLS LATENCY min=0 max=0
    ap_fixed<data_T::width + weight_T::width,
             data_T::iwidth + weight_T::iwidth> product;
#pragma HLS BIND_OP variable=product op=mul impl=dsp latency=0
    product = x * w;
    return product;
}

template<int GATE, int LEN, typename data_T, typename weight_T, typename accum_T>
accum_T Recurrent_Gate_MAC(data_T x[LEN], weight_T w[LEN]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=w complete dim=1
    static_assert(LEN == 5, "Wide accumulation is sized for five terms");
    typedef ap_fixed<accum_T::width + 3, accum_T::iwidth + 3, AP_RND, AP_SAT> wide_acc_t;
    typedef ap_fixed<accum_T::width, accum_T::iwidth, AP_RND, AP_WRAP> product_nosat_t;
    wide_acc_t acc = 0;
    acc += product_nosat_t(Recurrent_Term_Product<GATE, 0, data_T, weight_T>(x[0], w[0]));
    acc += product_nosat_t(Recurrent_Term_Product<GATE, 1, data_T, weight_T>(x[1], w[1]));
    acc += product_nosat_t(Recurrent_Term_Product<GATE, 2, data_T, weight_T>(x[2], w[2]));
    acc += product_nosat_t(Recurrent_Term_Product<GATE, 3, data_T, weight_T>(x[3], w[3]));
    acc += product_nosat_t(Recurrent_Term_Product<GATE, 4, data_T, weight_T>(x[4], w[4]));
    return accum_T(acc);
}

template<int GATE, int N, typename data_T, typename weight_T, typename accum_T>
void Recurrent_Gate_MVM(data_T x[N], weight_T W[N][N], accum_T y[N]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=2
#pragma HLS ARRAY_PARTITION variable=y complete dim=1
    for (int o = 0; o < N; o++) {
#pragma HLS UNROLL
        y[o] = Recurrent_Gate_MAC<GATE, N, data_T, weight_T, accum_T>(x, W[o]);
    }
}

// Separate GRU input MAC; other MVM users retain their original arithmetic.
template<int LEN, typename data_T, typename weight_T, typename accum_T>
accum_T Experiment_Input_MAC(data_T x[LEN], weight_T w[LEN]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=w complete dim=1
    static_assert(LEN == 5, "Wide accumulation is sized for five terms");
    typedef ap_fixed<accum_T::width + 3, accum_T::iwidth + 3, AP_RND, AP_SAT> wide_acc_t;
    wide_acc_t acc = 0;
    for (int i = 0; i < LEN; i++) {
#pragma HLS PIPELINE II=1
        acc += accum_T((x[i] * w[i]));
    }
    return accum_T(acc);
}

template<int IN_SIZE, int OUT_SIZE, typename data_T, typename weight_T, typename accum_T>
void Experiment_Input_MVM(data_T x[IN_SIZE], weight_T W[OUT_SIZE][IN_SIZE], accum_T y[OUT_SIZE]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=2
#pragma HLS ARRAY_PARTITION variable=y complete dim=1
    for (int o = 0; o < OUT_SIZE; o++) {
#pragma HLS UNROLL
        y[o] = Experiment_Input_MAC<IN_SIZE, data_T, weight_T, accum_T>(x, W[o]);
    }
}

// n gate only: distinct product functions for each row and input term.
template<int ROW, int TERM, typename data_T, typename weight_T>
ap_fixed<data_T::width + weight_T::width, data_T::iwidth + weight_T::iwidth>
Recurrent_Row_Product(data_T x, weight_T w) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1
#pragma HLS LATENCY min=0 max=0
    ap_fixed<data_T::width + weight_T::width,
             data_T::iwidth + weight_T::iwidth> product;
#pragma HLS BIND_OP variable=product op=mul impl=dsp latency=0
    product = x * w;
    return product;
}

template<int ROW, int LEN, typename data_T, typename weight_T, typename accum_T>
accum_T Recurrent_N_Row_MAC(data_T x[LEN], weight_T w[LEN]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=w complete dim=1
    static_assert(LEN == 5, "Wide accumulation is sized for five terms");
    typedef ap_fixed<accum_T::width + 3, accum_T::iwidth + 3, AP_RND, AP_SAT> wide_acc_t;
    typedef ap_fixed<accum_T::width, accum_T::iwidth, AP_RND, AP_WRAP> product_nosat_t;
    wide_acc_t acc = 0;
    acc += product_nosat_t(Recurrent_Row_Product<ROW, 0, data_T, weight_T>(x[0], w[0]));
    acc += product_nosat_t(Recurrent_Row_Product<ROW, 1, data_T, weight_T>(x[1], w[1]));
    acc += product_nosat_t(Recurrent_Row_Product<ROW, 2, data_T, weight_T>(x[2], w[2]));
    acc += product_nosat_t(Recurrent_Row_Product<ROW, 3, data_T, weight_T>(x[3], w[3]));
    acc += product_nosat_t(Recurrent_Row_Product<ROW, 4, data_T, weight_T>(x[4], w[4]));
    return accum_T(acc);
}

template<int N, typename data_T, typename weight_T, typename accum_T>
void Recurrent_N_Row_MVM(data_T x[N], weight_T W[N][N], accum_T y[N]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=2
#pragma HLS ARRAY_PARTITION variable=y complete dim=1
    static_assert(N == 5, "Row-specialized MVM requires five rows");
    y[0] = Recurrent_N_Row_MAC<0, N, data_T, weight_T, accum_T>(x, W[0]);
    y[1] = Recurrent_N_Row_MAC<1, N, data_T, weight_T, accum_T>(x, W[1]);
    y[2] = Recurrent_N_Row_MAC<2, N, data_T, weight_T, accum_T>(x, W[2]);
    y[3] = Recurrent_N_Row_MAC<3, N, data_T, weight_T, accum_T>(x, W[3]);
    y[4] = Recurrent_N_Row_MAC<4, N, data_T, weight_T, accum_T>(x, W[4]);
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
    Experiment_Input_MVM<IN_SIZE, HIDDEN_SIZE, data_T, weight_T, accum_T>(x, W_ir, W_ir_x);
    Experiment_Input_MVM<IN_SIZE, HIDDEN_SIZE, data_T, weight_T, accum_T>(x, W_iz, W_iz_x);
    Experiment_Input_MVM<IN_SIZE, HIDDEN_SIZE, data_T, weight_T, accum_T>(x, W_in, W_in_x);
 
    Recurrent_Gate_MVM<0, HIDDEN_SIZE, data_T, weight_T, accum_T>(h_prev, W_hr, W_hr_h);
    Recurrent_Gate_MVM<1, HIDDEN_SIZE, data_T, weight_T, accum_T>(h_prev, W_hz, W_hz_h);
    Recurrent_N_Row_MVM<HIDDEN_SIZE, data_T, weight_T, accum_T>(h_prev, W_hn, W_hn_h);
}
 

    struct config_a : nnet::activ_config {
        static const unsigned n_in = 1;
        static const unsigned table_size = 4096;
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
 
    data_T r_pre, z_pre, r, z, n, r_h, n_pre;
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
        nnet::sigmoid_comb<data_T, data_T, config_a>(r_pre, r);
        r_h = r * (W_hn_h[i] + b_hn_local[i]);
 
        n_pre = W_in_x[i] + b_in_local[i] + r_h;
        nnet::tanh_comb<data_T, data_T, config_a>(n_pre, n);
 
        z_pre = W_iz_x[i] + b_iz_local[i] + W_hz_h[i] + b_hz_local[i];
        nnet::sigmoid_comb<data_T, data_T, config_a>(z_pre, z);
        // Current sigmoid256 output fits unsigned Q0.12 for all Q3.12 inputs.
        // Preserve all fractional bits; only omit unused upper/sign bits of z.
        ap_ufixed<12,0> z_gate;
        z_gate.range(11,0) = z.range(11,0);
        // 0 <= z_gate < 1: the exact update stays between n and h_prev.
        // Preserve AP_RND and Q3.12; omit only the range-proven final clamp.
        typedef ap_fixed<data_T::width, data_T::iwidth, AP_RND, AP_WRAP> state_round_t;
        state_round_t h_rounded = n + z_gate * (h_prev[i] - n);
        h_next[i].range(data_T::width - 1, 0) = h_rounded.range(data_T::width - 1, 0);
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