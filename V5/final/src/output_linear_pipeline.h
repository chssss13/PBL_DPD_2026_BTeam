#pragma once
#include "input_linear_pipeline.h"

typedef ap_fixed<21,6,AP_RND,AP_SAT> output_acc_t;

// Preserve the original 21-bit saturating accumulation. Only the two
// completed sums cross this boundary: 42 bits, no products or input vector.
inline ap_uint<42> FastGRNN_OutputMACRegister(ap_uint<42> bits) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1
#pragma HLS LATENCY min=1 max=1
    return bits;
}

inline void OutputLinearPipelined(data_t x[H_SIZE],weight_t w[2][H_SIZE],
                                  data_t b[2],data_t y[2]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=w complete dim=0
#pragma HLS ARRAY_PARTITION variable=b complete dim=1
#pragma HLS ARRAY_PARTITION variable=y complete dim=1
    ap_uint<42> packed=0;
    for(int o=0;o<2;++o) {
#pragma HLS UNROLL
        output_acc_t acc=MAC_PE<H_SIZE,data_t,weight_t,output_acc_t>(x,w[o]);
        packed.range(21*o+20,21*o)=acc.range(20,0);
    }
    ap_uint<42> delayed=FastGRNN_OutputMACRegister(packed);
    for(int o=0;o<2;++o) {
#pragma HLS UNROLL
        output_acc_t acc;
        acc.range(20,0)=delayed.range(21*o+20,21*o);
        y[o]=acc+b[o];
    }
}
