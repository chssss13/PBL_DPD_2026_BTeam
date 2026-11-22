#include "res_fastgrnn.h"
#include "fastgrnn_cell.h"
#include "feature_pipeline.h"
#include "input_linear_pipeline.h"
#include "output_linear_pipeline.h"

void ResFastGRNN(
    data_t IQ_seq[TIME_STEP][2], data_t OUT_seq[TIME_STEP][2],
    weight_t W_inj[H_SIZE][6], data_t b_inj[H_SIZE],
    weight_t prelu_param, weight_t gating_params[NUM_LAYERS],
    weight_t W[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t U[NUM_LAYERS][H_SIZE][H_SIZE],
    data_t b_z[NUM_LAYERS][H_SIZE], data_t b_h[NUM_LAYERS][H_SIZE],
    weight_t zeta[NUM_LAYERS], weight_t nu[NUM_LAYERS],
    weight_t W_out[2][H_SIZE], data_t b_out[2], bool segment_start) {
#pragma HLS DATAFLOW
#pragma HLS ARRAY_PARTITION variable=W_inj complete dim=0
#pragma HLS ARRAY_PARTITION variable=b_inj complete dim=1
#pragma HLS ARRAY_PARTITION variable=gating_params complete dim=1
#pragma HLS ARRAY_PARTITION variable=W complete dim=0
#pragma HLS ARRAY_PARTITION variable=U complete dim=0
#pragma HLS ARRAY_PARTITION variable=b_z complete dim=0
#pragma HLS ARRAY_PARTITION variable=b_h complete dim=0
#pragma HLS ARRAY_PARTITION variable=zeta complete dim=1
#pragma HLS ARRAY_PARTITION variable=nu complete dim=1
#pragma HLS ARRAY_PARTITION variable=W_out complete dim=0
#pragma HLS ARRAY_PARTITION variable=b_out complete dim=1
    static data_t state[NUM_LAYERS][H_SIZE];
#pragma HLS ARRAY_PARTITION variable=state complete dim=0
    LOOP_T: for (int t=0; t<TIME_STEP; ++t) {
#pragma HLS PIPELINE II=2
        data_t raw_features[6], features[6], layer[NUM_LAYERS+1][H_SIZE], next[H_SIZE];
        accum_t projected[H_SIZE];
#pragma HLS ARRAY_PARTITION variable=features complete dim=1
#pragma HLS ARRAY_PARTITION variable=raw_features complete dim=1
#pragma HLS ARRAY_PARTITION variable=layer complete dim=0
#pragma HLS ARRAY_PARTITION variable=next complete dim=1
#pragma HLS ARRAY_PARTITION variable=projected complete dim=1
        FExLayer<data_t>(IQ_seq[t][0],IQ_seq[t][1],raw_features);
        RegisterFeatures(raw_features,features);
        InputLinearPipelined(features,W_inj,b_inj,projected);
        nnet::prelu<accum_t,data_t,weight_t,H_SIZE>(projected,layer[0],prelu_param);
        // Three distinct pipelines, each with its own distance-one recurrence.
#define FAST_LAYER(L) \
        FastGRNN_CellLayer<L>(layer[L],state[L],next,segment_start && t==0, \
                              W[L],U[L],b_z[L],b_h[L],zeta[L],nu[L]); \
        for(int i=0;i<H_SIZE;++i) { \
            _Pragma("HLS UNROLL") \
            state[L][i]=next[i]; \
            layer[(L)+1][i]=next[i]+gating_params[L]*layer[L][i]; \
        }
        FAST_LAYER(0)
        FAST_LAYER(1)
        FAST_LAYER(2)
#undef FAST_LAYER
        data_t output[2];
#pragma HLS ARRAY_PARTITION variable=output complete dim=1
        OutputLinearPipelined(layer[NUM_LAYERS],W_out,b_out,output);
        for(int o=0;o<2;++o) {
#pragma HLS UNROLL
            OUT_seq[t][o]=output[o];
        }
    }
}
