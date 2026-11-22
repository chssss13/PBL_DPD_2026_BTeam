#pragma once
#include "config.h"
#include "activations.h"

typedef ap_fixed<26,4,AP_RND,AP_SAT> scaled_t;

// One internal pipeline boundary. Return q/r without further quantization;
// the scheduler may balance this register across dot/activation operations.
template<int LAYER>
void FastGRNN_PrepareStage(data_t x[H_SIZE],data_t old[H_SIZE],
    weight_t W[H_SIZE][H_SIZE],weight_t U[H_SIZE][H_SIZE],
    data_t bz[H_SIZE],data_t bh[H_SIZE],weight_t zeta,weight_t nu,
    data_t z_out[H_SIZE],scaled_t q_out[H_SIZE],scaled_t r_out[H_SIZE]) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1
#pragma HLS LATENCY min=1 max=1
#pragma HLS ARRAY_PARTITION variable=x complete dim=1
#pragma HLS ARRAY_PARTITION variable=old complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=0
#pragma HLS ARRAY_PARTITION variable=U complete dim=0
#pragma HLS ARRAY_PARTITION variable=bz complete dim=1
#pragma HLS ARRAY_PARTITION variable=bh complete dim=1
#pragma HLS ARRAY_PARTITION variable=z_out complete dim=1
#pragma HLS ARRAY_PARTITION variable=q_out complete dim=1
#pragma HLS ARRAY_PARTITION variable=r_out complete dim=1
    typedef ap_fixed<21,6,AP_RND,AP_SAT> wide_acc_t;
    typedef ap_fixed<19,4,AP_RND,AP_SAT> shared_t;
    for(int o=0;o<H_SIZE;++o) {
#pragma HLS UNROLL
        wide_acc_t wx=0,uh=0;
        for(int i=0;i<H_SIZE;++i) {
#pragma HLS UNROLL
            wx+=accum_t(x[i]*W[o][i]);
            uh+=accum_t(old[i]*U[o][i]);
        }
        accum_t wx_q=wx,uh_q=uh;
        shared_t shared=wx_q+uh_q;
        data_t zpre=shared+bz[o],npre=shared+bh[o],z,n;
        nnet::sigmoid_comb<data_t,data_t,nnet::activ_config>(zpre,z);
        nnet::tanh_comb<data_t,data_t,nnet::activ_config>(npre,n);
        z_out[o]=z;
        q_out[o]=zeta*n;
        r_out[o]=nu*n;
    }
}

// A pure identity function with one cycle of latency MUST contain a register.
// Unlike a compute function of latency=1, it has no post-register arithmetic
// that can be chained into the next iteration's recurrent multiply.
template<int LAYER>
ap_uint<15*H_SIZE> FastGRNN_StateRegister(ap_uint<15*H_SIZE> bits) {
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1
#pragma HLS LATENCY min=1 max=1
    return bits;
}

template<int LAYER>
void FastGRNN_CellLayer(data_t x[H_SIZE],data_t prev[H_SIZE],data_t next[H_SIZE],bool reset,
    weight_t W[H_SIZE][H_SIZE],weight_t U[H_SIZE][H_SIZE],data_t bz[H_SIZE],data_t bh[H_SIZE],
    weight_t zeta,weight_t nu) {
#pragma HLS INLINE
    data_t old[H_SIZE],z[H_SIZE];scaled_t q[H_SIZE],r[H_SIZE];
#pragma HLS ARRAY_PARTITION variable=old complete dim=1
#pragma HLS ARRAY_PARTITION variable=z complete dim=1
#pragma HLS ARRAY_PARTITION variable=q complete dim=1
#pragma HLS ARRAY_PARTITION variable=r complete dim=1
    for(int i=0;i<H_SIZE;++i) {
#pragma HLS UNROLL
        old[i]=reset?data_t(0):prev[i];
    }
    FastGRNN_PrepareStage<LAYER>(x,old,W,U,bz,bh,zeta,nu,z,q,r);
    ap_uint<15*H_SIZE> state_bits=0;
    for(int i=0;i<H_SIZE;++i) {
#pragma HLS UNROLL
        typedef ap_fixed<41,7,AP_RND,AP_SAT> update_t;
        update_t wide=q[i]+r[i]+z[i]*(old[i]-q[i]);
        data_t value=wide;
        state_bits.range(15*i+14,15*i)=value.range(14,0);
    }
    ap_uint<15*H_SIZE> registered_bits=FastGRNN_StateRegister<LAYER>(state_bits);
    for(int i=0;i<H_SIZE;++i) {
#pragma HLS UNROLL
        next[i].range(14,0)=registered_bits.range(15*i+14,15*i);
    }
}

inline void FastGRNN_Cell(data_t x[H_SIZE],data_t prev[H_SIZE],data_t next[H_SIZE],bool reset,
    weight_t W[H_SIZE][H_SIZE],weight_t U[H_SIZE][H_SIZE],data_t bz[H_SIZE],data_t bh[H_SIZE],
    weight_t zeta,weight_t nu) {
    FastGRNN_CellLayer<3>(x,prev,next,reset,W,U,bz,bh,zeta,nu);
}
