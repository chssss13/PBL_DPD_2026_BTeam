#pragma once
#include "config.h"
#include "linear_layer.h"

// Five completed 18-bit MAC results, before bias/PReLU: 90 data bits.
// Keep all six saturating adds in their original order. Carry no tail inputs
// and no individual products across the clock boundary.
inline ap_uint<90> FastGRNN_InputMACRegister(ap_uint<90> bits) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1
#pragma HLS LATENCY min=1 max=1
    return bits;
}

inline void InputLinearPipelined(data_t x[6], weight_t w[H_SIZE][6],
                                 data_t b[H_SIZE], accum_t y[H_SIZE]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=w complete dim=0
#pragma HLS ARRAY_PARTITION variable=b complete dim=1
#pragma HLS ARRAY_PARTITION variable=y complete dim=1
    ap_uint<90> packed=0;
    for(int o=0;o<H_SIZE;++o) {
#pragma HLS UNROLL
        accum_t acc=MAC_PE<6,data_t,weight_t,accum_t>(x,w[o]);
        packed.range(18*o+17,18*o)=acc.range(17,0);
    }
    ap_uint<90> delayed=FastGRNN_InputMACRegister(packed);
    for(int o=0;o<H_SIZE;++o) {
#pragma HLS UNROLL
        accum_t acc;
        acc.range(17,0)=delayed.range(18*o+17,18*o);
        y[o]=acc+b[o];
    }
}
