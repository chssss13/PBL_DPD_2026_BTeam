
#include "multi_gru.h"
#include "gru_precompute.h"
//#include "linear_layer.h"
#include "utils.h"
#include <hls_stream.h>




void GRU_single(
    data_t x[I_SIZE],
    bool reset,
    data_t h_prev[H_SIZE],
    data_t h_next[H_SIZE],

    // New weight matrices (split into input and hidden)
    weight_t W_ir[H_SIZE][I_SIZE], weight_t W_hr[H_SIZE][H_SIZE],
    weight_t W_iz[H_SIZE][I_SIZE], weight_t W_hz[H_SIZE][H_SIZE],
    weight_t W_in[H_SIZE][I_SIZE], weight_t W_hn[H_SIZE][H_SIZE],

    // New biases (split)
    data_t b_ir[H_SIZE], data_t b_hr[H_SIZE],
    data_t b_iz[H_SIZE], data_t b_hz[H_SIZE],
    data_t b_in[H_SIZE], data_t b_hn[H_SIZE]
) {
#pragma HLS INLINE
    typedef ap_fixed<accum_t::width+2,accum_t::iwidth+2,AP_RND,AP_SAT> gate_t;
    typedef ap_fixed<accum_t::width+1,accum_t::iwidth+1,AP_RND,AP_SAT> hidden_n_t;
    gate_t input_r[H_SIZE], input_z[H_SIZE], input_n[H_SIZE];
    accum_t hidden_r[H_SIZE], hidden_z[H_SIZE];
    hidden_n_t hidden_n_bias[H_SIZE];
#pragma HLS ARRAY_PARTITION variable=input_r complete
#pragma HLS ARRAY_PARTITION variable=input_z complete
#pragma HLS ARRAY_PARTITION variable=input_n complete
#pragma HLS ARRAY_PARTITION variable=hidden_r complete
#pragma HLS ARRAY_PARTITION variable=hidden_z complete
#pragma HLS ARRAY_PARTITION variable=hidden_n_bias complete

    // No dependency on this layer's previous hidden state or reset selection.
    GRU_Prepare_Input_PE<I_SIZE,H_SIZE,data_t,weight_t,accum_t,gate_t>(
        x,W_ir,W_iz,W_in,b_ir,b_hr,b_iz,b_hz,b_in,input_r,input_z,input_n);

    data_t h_state[H_SIZE];
#pragma HLS ARRAY_PARTITION variable=h_state complete
#pragma HLS ARRAY_PARTITION variable=h_next complete
RESET_LOOP:
    for (int i=0;i<H_SIZE;++i) {
#pragma HLS UNROLL
        h_state[i] = reset ? data_t(0) : h_prev[i];
    }
    GRU_Prepare_Hidden_PE<H_SIZE,data_t,weight_t,accum_t,hidden_n_t>(
        h_state,W_hr,W_hz,W_hn,b_hn,hidden_r,hidden_z,hidden_n_bias);
    GRU_Gate_Precomputed_PE<H_SIZE,data_t,accum_t,gate_t,hidden_n_t>(
        input_r,input_z,input_n,hidden_r,hidden_z,hidden_n_bias,h_state,h_next);

}

void GRU_multi(
    const data_t x[I_SIZE],
    data_t y[H_SIZE],
    data_t h_state_all[NUM_LAYERS][H_SIZE],
    bool reset,
    weight_t W_ir[NUM_LAYERS][H_SIZE][I_SIZE],
    weight_t W_hr[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_iz[NUM_LAYERS][H_SIZE][I_SIZE],
    weight_t W_hz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_in[NUM_LAYERS][H_SIZE][I_SIZE],
    weight_t W_hn[NUM_LAYERS][H_SIZE][H_SIZE],
    data_t b_ir[NUM_LAYERS][H_SIZE], data_t b_hr[NUM_LAYERS][H_SIZE],
    data_t b_iz[NUM_LAYERS][H_SIZE], data_t b_hz[NUM_LAYERS][H_SIZE],
    data_t b_in[NUM_LAYERS][H_SIZE], data_t b_hn[NUM_LAYERS][H_SIZE]
){
    #pragma HLS INLINE
    #pragma HLS ARRAY_PARTITION variable=W_ir complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hr complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_iz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_in complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hn complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_ir complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_hr complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_iz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_hz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_in complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_hn complete dim=1

    /*
    #pragma HLS ARRAY_PARTITION variable=W_ir complete dim=2
    #pragma HLS ARRAY_PARTITION variable=W_hr complete dim=2
    #pragma HLS ARRAY_PARTITION variable=W_iz complete dim=2
    #pragma HLS ARRAY_PARTITION variable=W_hz complete dim=2
    #pragma HLS ARRAY_PARTITION variable=W_in complete dim=2
    #pragma HLS ARRAY_PARTITION variable=W_hn complete dim=2
    #pragma HLS ARRAY_PARTITION variable=b_ir complete dim=2
    #pragma HLS ARRAY_PARTITION variable=b_hr complete dim=2
    #pragma HLS ARRAY_PARTITION variable=b_iz complete dim=2
    #pragma HLS ARRAY_PARTITION variable=b_hz complete dim=2
    #pragma HLS ARRAY_PARTITION variable=b_in complete dim=2
    #pragma HLS ARRAY_PARTITION variable=b_hn complete dim=2
    */
    

    #pragma HLS ARRAY_PARTITION variable=h_state_all complete dim=1
    data_t layer_in[NUM_LAYERS][H_SIZE];
    data_t layer_out[NUM_LAYERS][H_SIZE];

    copy_row<I_SIZE>(x, layer_in[0]);
    
    MULTI_GRU :
    for (int l = 0; l < NUM_LAYERS; l++) {
        #pragma HLS PIPELINE
        GRU_single(
            layer_in[l], reset, h_state_all[l], layer_out[l],
            W_ir[l], W_hr[l],
            W_iz[l], W_hz[l],
            W_in[l], W_hn[l],
            b_ir[l], b_hr[l],
            b_iz[l], b_hz[l],
            b_in[l], b_hn[l]
        );

        copy_row<H_SIZE>(layer_out[l], h_state_all[l]);

        if (l < NUM_LAYERS - 1)
            copy_row<H_SIZE>(layer_out[l], layer_in[l+1]);
    }
    // layer_out[NUM_LAYERS-1] -> y_seq[t]
    copy_row<H_SIZE>(layer_out[NUM_LAYERS-1], y);
}


void MultiLayerGRU(
    data_t x_seq[TIME_STEP][I_SIZE],
    data_t y_seq[TIME_STEP][H_SIZE],
    bool reset,
    weight_t W_ir[NUM_LAYERS][H_SIZE][I_SIZE],
    weight_t W_hr[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_iz[NUM_LAYERS][H_SIZE][I_SIZE],
    weight_t W_hz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_in[NUM_LAYERS][H_SIZE][I_SIZE],
    weight_t W_hn[NUM_LAYERS][H_SIZE][H_SIZE],
    data_t b_ir[NUM_LAYERS][H_SIZE], data_t b_hr[NUM_LAYERS][H_SIZE],
    data_t b_iz[NUM_LAYERS][H_SIZE], data_t b_hz[NUM_LAYERS][H_SIZE],
    data_t b_in[NUM_LAYERS][H_SIZE], data_t b_hn[NUM_LAYERS][H_SIZE]
) {
    #pragma HLS DATAFLOW
    static data_t h_state_all[NUM_LAYERS][H_SIZE];
    #pragma HLS ARRAY_PARTITION variable=h_state_all complete dim=2

    for (int t = 0; t < TIME_STEP; t++) {
        #pragma HLS PIPELINE
        bool rst = reset || (t == 0);
        GRU_multi(
            x_seq[t], y_seq[t],h_state_all, rst,
            W_ir, W_hr,
            W_iz, W_hz,
            W_in, W_hn,
            b_ir, b_hr,
            b_iz, b_hz,
            b_in, b_hn
        );

    }
}

void ResJ_multi_GRU(
    const data_t x_in[H_SIZE],
    data_t y_out[H_SIZE],
    data_t h_state_all[NUM_LAYERS][H_SIZE],
    bool reset,
    weight_t gating_params[NUM_LAYERS],
    weight_t W_ir[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hr[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_iz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_in[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hn[NUM_LAYERS][H_SIZE][H_SIZE],
    data_t b_ir[NUM_LAYERS][H_SIZE], data_t b_hr[NUM_LAYERS][H_SIZE],
    data_t b_iz[NUM_LAYERS][H_SIZE], data_t b_hz[NUM_LAYERS][H_SIZE],
    data_t b_in[NUM_LAYERS][H_SIZE], data_t b_hn[NUM_LAYERS][H_SIZE]
){
    #pragma HLS INLINE
    #pragma HLS ARRAY_PARTITION variable=W_ir complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hr complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_iz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_in complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hn complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_ir complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_hr complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_iz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_hz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_in complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_hn complete dim=1
    

    #pragma HLS ARRAY_PARTITION variable=h_state_all complete dim=1

    // Buffers
    data_t x0[NUM_LAYERS][H_SIZE];            // persistent input copy
    #pragma HLS ARRAY_PARTITION variable=x0 complete dim=1
    #pragma HLS ARRAY_PARTITION variable=x0 complete dim=2
    data_t layer_in[NUM_LAYERS+1][H_SIZE];
    data_t layer_out[NUM_LAYERS][H_SIZE];

    // Input projection: copy x to x0
    copy_row<H_SIZE>(x_in, layer_in[0]);
    copy_row<H_SIZE>(x_in, x0[0]);

    LAYER_LOOP: for (int l = 0; l < NUM_LAYERS; l++) {
        #pragma HLS PIPELINE II=1

        GRU_single(
            layer_in[l], reset, h_state_all[l], layer_out[l],
            W_ir[l], W_hr[l],
            W_iz[l], W_hz[l],
            W_in[l], W_hn[l],
            b_ir[l], b_hr[l],
            b_iz[l], b_hz[l],
            b_in[l], b_hn[l]
        );
        
        // Update hidden state
        copy_row<H_SIZE>(layer_out[l], h_state_all[l]);

        // Inject persistent x0 at every layer
        if (l <= NUM_LAYERS - 1) {
            RES_J : 
            for (int i = 0; i < H_SIZE; i++) {
                #pragma HLS UNROLL
                layer_in[l+1][i] = layer_out[l][i] + gating_params[l] * x0[l][i];  // x_{n+1} = f(x_n) + x_0
            }
            copy_row<I_SIZE>(x0[l], x0[l+1]);
        }
        copy_row<H_SIZE>(layer_in[NUM_LAYERS],y_out);
    }

    // Final output
    
}

void ResGRU(
    data_t IQ_seq[TIME_STEP][2],
    data_t OUT_seq[TIME_STEP][2],

    weight_t W_inj[H_SIZE][6],
    data_t b_inj[H_SIZE],
    weight_t prelu_param,
    weight_t gating_params[NUM_LAYERS],

    weight_t W_ir[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hr[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_iz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_in[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hn[NUM_LAYERS][H_SIZE][H_SIZE],
    data_t b_ir[NUM_LAYERS][H_SIZE], data_t b_hr[NUM_LAYERS][H_SIZE],
    data_t b_iz[NUM_LAYERS][H_SIZE], data_t b_hz[NUM_LAYERS][H_SIZE],
    data_t b_in[NUM_LAYERS][H_SIZE], data_t b_hn[NUM_LAYERS][H_SIZE],

    weight_t W_out[2][H_SIZE],
    data_t b_out[2],
    bool reset_segment
) {
    #pragma HLS DATAFLOW

    static data_t h_state_all[NUM_LAYERS][H_SIZE];
    #pragma HLS ARRAY_PARTITION variable=h_state_all complete dim=1
    #pragma HLS ARRAY_PARTITION variable=h_state_all complete dim=2
    data_t gru_in[H_SIZE], gru_out[H_SIZE];
    data_t x_w_fex[6];
    accum_t x_inj[H_SIZE];
    #pragma HLS ARRAY_PARTITION variable=W_inj complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_inj complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_out complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_out complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_inj complete dim=2
    #pragma HLS ARRAY_PARTITION variable=b_inj complete dim=2
    #pragma HLS ARRAY_PARTITION variable=W_out complete dim=2
    #pragma HLS ARRAY_PARTITION variable=b_out complete dim=2
    #pragma HLS ARRAY_PARTITION variable=W_hr complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_iz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_in complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_hn complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_ir complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_hr complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_iz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_hz complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_in complete dim=1
    #pragma HLS ARRAY_PARTITION variable=b_hn complete dim=1
    #pragma HLS ARRAY_PARTITION variable=W_ir complete dim=1

    data_t layer_in[NUM_LAYERS+1][H_SIZE];
    data_t layer_out[NUM_LAYERS][H_SIZE];

    LOOP_T: for (int t = 0; t < TIME_STEP; t++) {
        #pragma HLS PIPELINE II=2

        bool rst = reset_segment && (t == 0);

        FEx : FExLayerNormalized<data_t,fex_inv_t,FEX_NR_ITERATIONS>(IQ_seq[t][0],IQ_seq[t][1],x_w_fex);

        IN_INJECT : Linear<6,H_SIZE,data_t,weight_t,accum_t>(x_w_fex, W_inj, b_inj, x_inj);

        PReLU : nnet::prelu<accum_t,data_t,weight_t,H_SIZE>(x_inj, gru_in,prelu_param);
        // Buffers

        // Input projection: copy x to x0
        copy_row<H_SIZE>(gru_in, layer_in[0]);
        LAYER_LOOP: for (int l = 0; l < NUM_LAYERS; l++) {
            #pragma HLS PIPELINE

            GRU_single(
                layer_in[l], rst, h_state_all[l], layer_out[l],
                W_ir[l], W_hr[l],
                W_iz[l], W_hz[l],
                W_in[l], W_hn[l],
                b_ir[l], b_hr[l],
                b_iz[l], b_hz[l],
                b_in[l], b_hn[l]
            );
            
            // Update hidden state
            copy_row<H_SIZE>(layer_out[l], h_state_all[l]);

            // Inject persistent x0 at every layer
            if (l <= NUM_LAYERS - 1) {
                RES_J : 
                for (int i = 0; i < H_SIZE; i++) {
                    #pragma HLS UNROLL
                    layer_in[l+1][i] = layer_out[l][i] + gating_params[l] * layer_in[l][i];  // x_{n+1} = f(x_n) + x_0
                }
            }
            copy_row<H_SIZE>(layer_in[NUM_LAYERS],gru_out);
        }


        OUT : Linear<H_SIZE,2,data_t,weight_t,data_t>(gru_out,W_out,b_out, OUT_seq[t]);
    }
}


