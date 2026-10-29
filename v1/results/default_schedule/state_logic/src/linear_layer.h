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


#ifndef FEX_INTERNAL_FIXED
#define FEX_INTERNAL_FIXED 1
#endif
#ifndef FEX_INV_I
#define FEX_INV_I 8
#endif

template<typename data_T>
void FExLayer(data_T Ix, data_T Qx, data_T out[6]) {
#pragma HLS INLINE
//#pragma HLS PIPELINE II=1
#pragma HLS ARRAY_PARTITION variable=out complete dim=1

#if FEX_INTERNAL_FIXED
    // Match v1.2: explicit 16-bit intermediate assignments.
    // sqrt/reciprocal and activations still use double math internally.
    typedef ap_fixed<16,FEX_INV_I,AP_RND,AP_SAT> inv_t;
    const data_T i2 = Ix * Ix;
    const data_T q2 = Qx * Qx;
    const data_T amp2 = i2 + q2;
    const data_T amp = std::sqrt(amp2.to_double());
    const inv_t inv = amp > data_T(0) ? inv_t(1.0 / amp.to_double()) : inv_t(0);
    const data_T amp_sq = amp * amp;
    const data_T amp3 = amp_sq * amp;
    out[0] = Ix;
    out[1] = Qx;
    out[2] = amp;
    out[3] = amp3;
    out[4] = Qx * inv;
    out[5] = Ix * inv;
#else
    // Match hw_ref.py --fex exact: quantize outputs, not intermediate math.
    // Accuracy reference only; replace after checking hardware cost.
    const double i = Ix.to_double();
    const double q = Qx.to_double();
    const double amp = std::sqrt(i * i + q * q);
    const double inv = amp > 0.0 ? 1.0 / amp : 0.0;
    out[0] = Ix;
    out[1] = Qx;
    out[2] = amp;
    out[3] = amp * amp * amp;
    out[4] = q * inv;
    out[5] = i * inv;
#endif
}

