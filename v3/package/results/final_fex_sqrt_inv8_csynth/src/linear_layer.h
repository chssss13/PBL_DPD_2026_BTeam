#include <cmath>
#include "activations.h"
#include "fxp_sqrt.h"

template<int LEN, typename data_T, typename weight_T, typename accum_T>
accum_T MAC_PE(data_T x[LEN], weight_T w[LEN]) {
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=w complete dim=1
#pragma HLS INLINE
    accum_T acc = 0;
    for (int i = 0; i < LEN; i++) {
        #pragma HLS PIPELINE II=1
        acc += accum_T(x[i] * w[i]);
    }
    return acc;
}
 
template<int IN_SIZE, int OUT_SIZE, typename data_T, typename weight_T, typename accum_T>
void MVM_PE(data_T x[IN_SIZE], weight_T W[OUT_SIZE][IN_SIZE], accum_T y[OUT_SIZE]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=2
#pragma HLS ARRAY_PARTITION variable=y complete dim=1
 
MVM_LOOP_OUT:
    for (int o = 0; o < OUT_SIZE; o++) {
        #pragma HLS UNROLL
        y[o] = MAC_PE<IN_SIZE, data_T, weight_T, accum_T>(x, W[o]);
    }
}

template<int IN_SIZE, int OUT_SIZE, typename data_T, typename weight_T, typename accum_T>
void Linear(data_T x[IN_SIZE], weight_T W[OUT_SIZE][IN_SIZE], data_T b[OUT_SIZE] , accum_T y[OUT_SIZE]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=2
#pragma HLS ARRAY_PARTITION variable=b complete dim=1
#pragma HLS ARRAY_PARTITION variable=y complete dim=1
 
    MVM_LOOP_OUT:
    for (int o = 0; o < OUT_SIZE; o++) {
        #pragma HLS UNROLL
        y[o] = MAC_PE<IN_SIZE, data_T, weight_T, accum_T>(x, W[o]) + b[o];
    }
}


template<typename data_T>
void FExLayer(data_T Ix, data_T Qx, data_T out[6]) {
#pragma HLS INLINE
//#pragma HLS PIPELINE II=1
#pragma HLS ARRAY_PARTITION variable=out complete dim=1

    typedef ap_fixed<16,8,AP_RND,AP_SAT> inverse_t;
    const data_T i2 = Ix * Ix;
    const data_T q2 = Qx * Qx;
    const data_T amp2 = i2 + q2;
    const data_T amp = std::sqrt(amp2.to_double());
    const inverse_t inv = amp > data_T(0) ? inverse_t(1.0 / amp.to_double()) : inverse_t(0);
    const data_T amp_sq = amp * amp;
    const data_T amp3 = amp_sq * amp;
    const data_T sin_theta = Qx * inv;
    const data_T cos_theta = Ix * inv;

    // assign output
    out[0] = Ix;
    out[1] = Qx;
    out[2] = amp;
    out[3] = amp3;
    out[4] = sin_theta;
    out[5] = cos_theta;
}

