#pragma once
#include "gru_cell.h"

// E18 arithmetic with explicit dependency separation. INLINE does not force
// new clock boundaries; scheduling/II/timing must be checked separately.
template<int IN_SIZE, int HIDDEN_SIZE, typename data_T, typename weight_T,
         typename accum_T, typename gate_T>
void GRU_Prepare_Input_PE(
    data_T x[IN_SIZE],
    weight_T W_ir[HIDDEN_SIZE][IN_SIZE], weight_T W_iz[HIDDEN_SIZE][IN_SIZE],
    weight_T W_in[HIDDEN_SIZE][IN_SIZE],
    data_T b_ir[HIDDEN_SIZE], data_T b_hr[HIDDEN_SIZE],
    data_T b_iz[HIDDEN_SIZE], data_T b_hz[HIDDEN_SIZE], data_T b_in[HIDDEN_SIZE],
    gate_T input_r[HIDDEN_SIZE], gate_T input_z[HIDDEN_SIZE], gate_T input_n[HIDDEN_SIZE]
) {
#pragma HLS INLINE
    static_assert(gate_T::width-gate_T::iwidth >= accum_T::width-accum_T::iwidth,
                  "Input precomputation must preserve accumulator fractional bits");
    static_assert(gate_T::width-gate_T::iwidth >= data_T::width-data_T::iwidth,
                  "Input precomputation must preserve bias fractional bits");
    static_assert(gate_T::iwidth >= accum_T::iwidth+2 && gate_T::iwidth >= data_T::iwidth+2,
                  "Guard range required for one MAC and two biases");
    accum_T ir[HIDDEN_SIZE], iz[HIDDEN_SIZE], in[HIDDEN_SIZE];
#pragma HLS ARRAY_PARTITION variable=ir complete
#pragma HLS ARRAY_PARTITION variable=iz complete
#pragma HLS ARRAY_PARTITION variable=in complete
    MVM_PE<IN_SIZE,HIDDEN_SIZE,data_T,weight_T,accum_T>(x,W_ir,ir);
    MVM_PE<IN_SIZE,HIDDEN_SIZE,data_T,weight_T,accum_T>(x,W_iz,iz);
    MVM_PE<IN_SIZE,HIDDEN_SIZE,data_T,weight_T,accum_T>(x,W_in,in);
PREPARE_INPUT_BIAS:
    for (int i=0;i<HIDDEN_SIZE;++i) {
#pragma HLS UNROLL
        // Every operand has <= Fgate fractional bits and the sum fits gate_T.
        // These assignments therefore introduce no new rounding/saturation.
        input_r[i] = gate_T(ir[i]) + gate_T(b_ir[i]) + gate_T(b_hr[i]);
        input_z[i] = gate_T(iz[i]) + gate_T(b_iz[i]) + gate_T(b_hz[i]);
        input_n[i] = gate_T(in[i]) + gate_T(b_in[i]);
    }
}

template<int HIDDEN_SIZE, typename data_T, typename weight_T,
         typename accum_T, typename hidden_n_T>
void GRU_Prepare_Hidden_PE(
    data_T h_prev[HIDDEN_SIZE],
    weight_T W_hr[HIDDEN_SIZE][HIDDEN_SIZE], weight_T W_hz[HIDDEN_SIZE][HIDDEN_SIZE],
    weight_T W_hn[HIDDEN_SIZE][HIDDEN_SIZE], data_T b_hn[HIDDEN_SIZE],
    accum_T hidden_r[HIDDEN_SIZE], accum_T hidden_z[HIDDEN_SIZE],
    hidden_n_T hidden_n_bias[HIDDEN_SIZE]
) {
#pragma HLS INLINE
    static_assert(hidden_n_T::width == accum_T::width+1 &&
                  hidden_n_T::iwidth == accum_T::iwidth+1,
                  "Retain E18 hidden candidate sum width before reset product");
    static_assert(data_T::width-data_T::iwidth <= accum_T::width-accum_T::iwidth &&
                  data_T::iwidth <= accum_T::iwidth,
                  "Bias must fit the hidden sum fractional precision and range");
    accum_T hn[HIDDEN_SIZE];
#pragma HLS ARRAY_PARTITION variable=hn complete
    MVM_PE<HIDDEN_SIZE,HIDDEN_SIZE,data_T,weight_T,accum_T>(h_prev,W_hr,hidden_r);
    MVM_PE<HIDDEN_SIZE,HIDDEN_SIZE,data_T,weight_T,accum_T>(h_prev,W_hz,hidden_z);
    MVM_PE<HIDDEN_SIZE,HIDDEN_SIZE,data_T,weight_T,accum_T>(h_prev,W_hn,hn);
PREPARE_HIDDEN_N_BIAS:
    for (int i=0;i<HIDDEN_SIZE;++i) {
#pragma HLS UNROLL
        // Independent of r, but still dependent on h_prev.
        // Width/F match E18's automatic type of (W_hn_h + b_hn).
        hidden_n_bias[i] = hn[i] + b_hn[i];
    }
}

template<int HIDDEN_SIZE, typename data_T, typename accum_T,
         typename gate_T, typename hidden_n_T>
void GRU_Gate_Precomputed_PE(
    gate_T input_r[HIDDEN_SIZE], gate_T input_z[HIDDEN_SIZE], gate_T input_n[HIDDEN_SIZE],
    accum_T hidden_r[HIDDEN_SIZE], accum_T hidden_z[HIDDEN_SIZE],
    hidden_n_T hidden_n_bias[HIDDEN_SIZE], data_T h_prev[HIDDEN_SIZE], data_T h_next[HIDDEN_SIZE]
) {
#pragma HLS INLINE
GATE_PRECOMPUTED_LOOP:
    for (int i=0;i<HIDDEN_SIZE;++i) {
#pragma HLS UNROLL factor=1
#pragma HLS PIPELINE II=1
        // z and the retained state do not depend on the r -> n branch.
        gate_T z_pre = input_z[i] + hidden_z[i];
        data_T z;
        nnet::sigmoid_lut<gate_T,data_T>(z_pre,z);
        data_T one_minus_z = data_T(1.0) - z;
        auto retained_product = z * h_prev[i];
#pragma HLS BIND_OP variable=retained_product op=mul impl=dsp latency=0

        gate_T r_pre = input_r[i] + hidden_r[i];
        data_T r;
        nnet::sigmoid_lut<gate_T,data_T>(r_pre,r);
        auto reset_product = r * hidden_n_bias[i];
#pragma HLS BIND_OP variable=reset_product op=mul impl=dsp latency=0
        gate_T r_h = reset_product;
        gate_T n_pre = input_n[i] + r_h;
        data_T n;
        nnet::tanh_lut<gate_T,data_T>(n_pre,n);
        auto candidate_product = one_minus_z * n;
#pragma HLS BIND_OP variable=candidate_product op=mul impl=dsp latency=0
        h_next[i] = candidate_product + retained_product;
    }
}
