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

    data_T amp, amp2, amp3, phase, sin_theta, cos_theta;

    // magnitude
    
    amp2 = Ix * Ix + Qx * Qx;

    data_T delta = amp2 - data_T(1);
    typedef ap_fixed<16,6,AP_RND,AP_SAT> inverse_t;
    inverse_t inv_sqrt = data_T(1) - data_T(0.5) * delta + data_T(0.375) * delta * delta; //taylor expansion for newton-raphson init

    //#pragma HLS PIPELINE
    for (int i = 0; i < 4; i++) {
        inv_sqrt = inv_sqrt * (data_T(1.5) - data_T(0.5) * amp2 * inv_sqrt * inv_sqrt); // newton-raphson 4 iteration without divide
    }

    amp = amp2 * inv_sqrt;
    amp3 = amp * amp2;
    sin_theta = Qx * inv_sqrt;
    cos_theta = Ix * inv_sqrt;

    // assign output
    out[0] = Ix;
    out[1] = Qx;
    out[2] = amp;
    out[3] = amp3;
    out[4] = sin_theta;
    out[5] = cos_theta;
}

