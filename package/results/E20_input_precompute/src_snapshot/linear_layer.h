#include "activations.h"
#include "fxp_sqrt.h"

template<int LEN, typename data_T, typename weight_T, typename accum_T>
accum_T MAC_PE(data_T x[LEN], weight_T w[LEN]) {
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=w complete dim=1
#pragma HLS INLINE
    // Retain the original product quantization. Three guard bits allow a
    // balanced sum of up to eight terms, then saturate at the MAC output.
    static_assert(LEN <= 8, "MAC tree guard-bit bound");
    typedef ap_fixed<accum_T::width+3,accum_T::iwidth+3> sum_t;
    sum_t partial[8];
#pragma HLS ARRAY_PARTITION variable=partial complete
    for(int i=0;i<8;++i) {
#pragma HLS UNROLL
        partial[i] = i<LEN ? sum_t(accum_T(x[i]*w[i])) : sum_t(0);
    }
    for(int stride=4;stride>0;stride/=2) {
#pragma HLS UNROLL
        for(int i=0;i<stride;++i) {
#pragma HLS UNROLL
            partial[i]=partial[2*i]+partial[2*i+1];
        }
    }
    return accum_T(partial[0]);
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


template<typename data_T, typename inv_T = data_T, int NR_ITERATIONS = 4>
void FExLayer(data_T Ix, data_T Qx, data_T out[6]) {
#pragma HLS INLINE
//#pragma HLS PIPELINE II=1
#pragma HLS ARRAY_PARTITION variable=out complete dim=1

    data_T amp, amp2, amp3, phase, sin_theta, cos_theta;

    // magnitude
    
    amp2 = Ix * Ix + Qx * Qx;

    data_T delta = amp2 - data_T(1);
    inv_T inv_sqrt = data_T(1) - data_T(0.5) * delta + data_T(0.375) * delta * delta; //taylor expansion for newton-raphson init

    //#pragma HLS PIPELINE
    for (int i = 0; i < NR_ITERATIONS; i++) {
        inv_sqrt = inv_sqrt * (data_T(1.5) - data_T(0.5) * amp2 * inv_sqrt * inv_sqrt);
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

// Scale I/Q together by powers of two before squaring. All stored numeric
// intermediates remain 16-bit; inverse storage is supplied by inv_T.
template<typename data_T, typename inv_T, int NR_ITERATIONS = 4>
void FExLayerNormalized(data_T Ix, data_T Qx, data_T out[6]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=out complete dim=1
    typedef ap_ufixed<16,2,AP_RND,AP_SAT> magnitude_t;
    out[0] = Ix;
    out[1] = Qx;
    if (Ix == 0 && Qx == 0) {
        for (int k = 2; k < 6; ++k) {
#pragma HLS UNROLL
            out[k] = 0;
        }
        return;
    }
    magnitude_t abs_i = Ix < 0 ? magnitude_t(data_T(0)-Ix) : magnitude_t(Ix);
    magnitude_t abs_q = Qx < 0 ? magnitude_t(data_T(0)-Qx) : magnitude_t(Qx);
    magnitude_t peak = abs_i > abs_q ? abs_i : abs_q;
    magnitude_t restore = 1;
    data_T ni = Ix, nq = Qx;
    if (peak >= 1) {
        ni = data_T(ni * data_T(0.5));
        nq = data_T(nq * data_T(0.5));
        peak = magnitude_t(peak * magnitude_t(0.5));
        restore = 2;
    }
    // Smallest nonzero Q14 input reaches 0.5 after 13 left shifts.
    for (int k = 0; k < 14; ++k) {
#pragma HLS UNROLL
        if (peak < magnitude_t(0.5)) {
            ni = data_T(ni * 2);
            nq = data_T(nq * 2);
            peak = magnitude_t(peak * 2);
            restore = magnitude_t(restore * magnitude_t(0.5));
        }
    }
    // Unsigned UQ2.14 includes the boundary value 2 for e.g. (-2,-2).
    magnitude_t norm_amp2 = ni * ni + nq * nq;
    data_T delta = norm_amp2 - data_T(1);
    inv_T inverse = data_T(1) - data_T(0.5)*delta + data_T(0.375)*delta*delta;
    for (int k = 0; k < NR_ITERATIONS; ++k) {
        inverse = inverse * (data_T(1.5) - data_T(0.5)*norm_amp2*inverse*inverse);
    }
    data_T norm_amp = norm_amp2 * inverse;
    data_T amp = norm_amp * restore;
    data_T raw_amp2 = Ix * Ix + Qx * Qx;
    out[2] = amp;
    out[3] = amp * raw_amp2;
    out[4] = nq * inverse;
    out[5] = ni * inverse;
}

