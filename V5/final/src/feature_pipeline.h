#pragma once
#include "config.h"

// Register the COMPLETED features, preserving all six Q3.12 bit patterns.
// Identity-only latency=1 prevents combinational arithmetic after this register
// inside the helper. This stage is outside the hidden-state recurrence.
inline ap_uint<90> FastGRNN_FeatureRegister(ap_uint<90> bits) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1
#pragma HLS LATENCY min=1 max=1
    return bits;
}

inline void RegisterFeatures(data_t raw[6],data_t registered[6]) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=raw complete dim=1
#pragma HLS ARRAY_PARTITION variable=registered complete dim=1
    ap_uint<90> packed=0;
    for(int f=0;f<6;++f) {
#pragma HLS UNROLL
        packed.range(15*f+14,15*f)=raw[f].range(14,0);
    }
    ap_uint<90> delayed=FastGRNN_FeatureRegister(packed);
    for(int f=0;f<6;++f) {
#pragma HLS UNROLL
        registered[f].range(14,0)=delayed.range(15*f+14,15*f);
    }
}
