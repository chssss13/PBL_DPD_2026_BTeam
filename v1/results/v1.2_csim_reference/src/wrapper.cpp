
#include "multi_gru.h"
#include "utils.h"
#include <hls_stream.h>

// Dispatcher: write weight

#include "multi_gru.h"
#include "utils.h"
#include <hls_stream.h>

// Dispatcher: write weight (extended to GRU core)
void weight_write_unit(int addr, weight_t val,
    weight_t W_inj[H_SIZE][6],
    data_t b_inj[H_SIZE],
    weight_t &prelu_param,
    weight_t gating_params[NUM_LAYERS],
    weight_t W_out[2][H_SIZE],
    data_t b_out[2],
    weight_t W_ir[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hr[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_iz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hz[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_in[NUM_LAYERS][H_SIZE][H_SIZE],
    weight_t W_hn[NUM_LAYERS][H_SIZE][H_SIZE],
    data_t b_ir[NUM_LAYERS][H_SIZE],
    data_t b_hr[NUM_LAYERS][H_SIZE],
    data_t b_iz[NUM_LAYERS][H_SIZE],
    data_t b_hz[NUM_LAYERS][H_SIZE],
    data_t b_in[NUM_LAYERS][H_SIZE],
    data_t b_hn[NUM_LAYERS][H_SIZE]
) {
#pragma HLS INLINE
    if (addr >= 0 && addr < H_SIZE * 6) {
        int i = addr / 6;
        int j = addr % 6;
        W_inj[i][j] = val;
    } else if (addr >= 100 && addr < 100 + H_SIZE) {
        b_inj[addr - 100] = val;
    } else if (addr == 1000) {
        prelu_param = val;
    } else if (addr >= 1010 && addr < 1010 + NUM_LAYERS) {
        gating_params[addr - 1010] = val;
    } else if (addr >= 2000 && addr < 2000 + 2 * H_SIZE) {
        int i = (addr - 2000) / H_SIZE;
        int j = (addr - 2000) % H_SIZE;
        W_out[i][j] = val;
    } else if (addr >= 2100 && addr < 2102) {
        b_out[addr - 2100] = val;
    } else if (addr >= 3000 && addr < 3000 + NUM_LAYERS * H_SIZE * H_SIZE) {
        int flat = addr - 3000;
        int l = flat / (H_SIZE * H_SIZE);
        int i = (flat / H_SIZE) % H_SIZE;
        int j = flat % H_SIZE;
        W_ir[l][i][j] = val;
    } else if (addr >= 4000 && addr < 4000 + NUM_LAYERS * H_SIZE * H_SIZE) {
        int flat = addr - 4000;
        int l = flat / (H_SIZE * H_SIZE);
        int i = (flat / H_SIZE) % H_SIZE;
        int j = flat % H_SIZE;
        W_hr[l][i][j] = val;
    } else if (addr >= 5000 && addr < 5000 + NUM_LAYERS * H_SIZE * H_SIZE) {
        int flat = addr - 5000;
        int l = flat / (H_SIZE * H_SIZE);
        int i = (flat / H_SIZE) % H_SIZE;
        int j = flat % H_SIZE;
        W_iz[l][i][j] = val;
    } else if (addr >= 6000 && addr < 6000 + NUM_LAYERS * H_SIZE * H_SIZE) {
        int flat = addr - 6000;
        int l = flat / (H_SIZE * H_SIZE);
        int i = (flat / H_SIZE) % H_SIZE;
        int j = flat % H_SIZE;
        W_hz[l][i][j] = val;
    } else if (addr >= 7000 && addr < 7000 + NUM_LAYERS * H_SIZE * H_SIZE) {
        int flat = addr - 7000;
        int l = flat / (H_SIZE * H_SIZE);
        int i = (flat / H_SIZE) % H_SIZE;
        int j = flat % H_SIZE;
        W_in[l][i][j] = val;
    } else if (addr >= 8000 && addr < 8000 + NUM_LAYERS * H_SIZE * H_SIZE) {
        int flat = addr - 8000;
        int l = flat / (H_SIZE * H_SIZE);
        int i = (flat / H_SIZE) % H_SIZE;
        int j = flat % H_SIZE;
        W_hn[l][i][j] = val;
    } else if (addr >= 9000 && addr < 9000 + NUM_LAYERS * H_SIZE) {
        int flat = addr - 9000;
        b_ir[flat / H_SIZE][flat % H_SIZE] = val;
    } else if (addr >= 10000 && addr < 10000 + NUM_LAYERS * H_SIZE) {
        int flat = addr - 10000;
        b_hr[flat / H_SIZE][flat % H_SIZE] = val;
    } else if (addr >= 11000 && addr < 11000 + NUM_LAYERS * H_SIZE) {
        int flat = addr - 11000;
        b_iz[flat / H_SIZE][flat % H_SIZE] = val;
    } else if (addr >= 12000 && addr < 12000 + NUM_LAYERS * H_SIZE) {
        int flat = addr - 12000;
        b_hz[flat / H_SIZE][flat % H_SIZE] = val;
    } else if (addr >= 13000 && addr < 13000 + NUM_LAYERS * H_SIZE) {
        int flat = addr - 13000;
        b_in[flat / H_SIZE][flat % H_SIZE] = val;
    } else if (addr >= 14000 && addr < 14000 + NUM_LAYERS * H_SIZE) {
        int flat = addr - 14000;
        b_hn[flat / H_SIZE][flat % H_SIZE] = val;
    }
}

// ResJGRU wrapper
void Res_HW_wrapper(
    data_t IQ_w[2],
    int IQ_w_addr,
    data_t &IQ_r_0,
    data_t &IQ_r_1,
    int IQ_r_address,
    weight_t weight_w,
    int weight_waddr
) {
    // Input/output feature memory
    static data_t IQ_seq[TIME_STEP][2];
    #pragma HLS BIND_STORAGE variable=IQ_seq type=RAM_2P impl=bram
    #pragma HLS ARRAY_PARTITION variable=IQ_seq complete dim=2

    static data_t OUT_seq[TIME_STEP][2];
    #pragma HLS BIND_STORAGE variable=OUT_seq type=RAM_2P impl=bram
    #pragma HLS ARRAY_PARTITION variable=OUT_seq complete dim=2

    // Input projection
    static weight_t W_inj[H_SIZE][6];
    #pragma HLS BIND_STORAGE variable=W_inj type=RAM_1P impl=uram
    #pragma HLS ARRAY_PARTITION variable=W_inj complete dim=2

    static data_t b_inj[H_SIZE];
    #pragma HLS BIND_STORAGE variable=b_inj type=RAM_1P impl=bram
    #pragma HLS ARRAY_PARTITION variable=b_inj complete dim=1

    // GRU Weights & Biases
    static weight_t W_ir[NUM_LAYERS][H_SIZE][H_SIZE];
    #pragma HLS BIND_STORAGE variable=W_ir type=RAM_1P impl=bram

    static weight_t W_hr[NUM_LAYERS][H_SIZE][H_SIZE];
    #pragma HLS BIND_STORAGE variable=W_hr type=RAM_1P impl=bram

    static weight_t W_iz[NUM_LAYERS][H_SIZE][H_SIZE];
    #pragma HLS BIND_STORAGE variable=W_iz type=RAM_1P impl=bram

    static weight_t W_hz[NUM_LAYERS][H_SIZE][H_SIZE];
    #pragma HLS BIND_STORAGE variable=W_hz type=RAM_1P impl=bram

    static weight_t W_in[NUM_LAYERS][H_SIZE][H_SIZE];
    #pragma HLS BIND_STORAGE variable=W_in type=RAM_1P impl=bram

    static weight_t W_hn[NUM_LAYERS][H_SIZE][H_SIZE];
    #pragma HLS BIND_STORAGE variable=W_hn type=RAM_1P impl=bram

    static data_t b_ir[NUM_LAYERS][H_SIZE];
    #pragma HLS BIND_STORAGE variable=b_ir type=RAM_1P impl=bram

    static data_t b_hr[NUM_LAYERS][H_SIZE];
    #pragma HLS BIND_STORAGE variable=b_hr type=RAM_1P impl=bram

    static data_t b_iz[NUM_LAYERS][H_SIZE];
    #pragma HLS BIND_STORAGE variable=b_iz type=RAM_1P impl=bram

    static data_t b_hz[NUM_LAYERS][H_SIZE];
    #pragma HLS BIND_STORAGE variable=b_hz type=RAM_1P impl=bram

    static data_t b_in[NUM_LAYERS][H_SIZE];
    #pragma HLS BIND_STORAGE variable=b_in type=RAM_1P impl=bram

    static data_t b_hn[NUM_LAYERS][H_SIZE];
    #pragma HLS BIND_STORAGE variable=b_hn type=RAM_1P impl=bram

    // Output layer
    static weight_t W_out[2][H_SIZE];
    #pragma HLS BIND_STORAGE variable=W_out type=RAM_1P impl=bram
    #pragma HLS ARRAY_PARTITION variable=W_out complete dim=1

    static data_t b_out[2];
    #pragma HLS BIND_STORAGE variable=b_out type=RAM_1P impl=bram
    #pragma HLS ARRAY_PARTITION variable=b_out complete dim=1

    // Gating & prelu
    static weight_t gating_params[NUM_LAYERS];
    #pragma HLS BIND_STORAGE variable=gating_params type=RAM_1P impl=bram

    static weight_t prelu_param;
    #pragma HLS BIND_STORAGE variable=prelu_param type=RAM_1P impl=bram



    // Write input sample
    IQ_seq[IQ_w_addr][0] = IQ_w[0];
    IQ_seq[IQ_w_addr][1] = IQ_w[1];

    // Write weight (if valid)
    if (weight_waddr >= 0)
        weight_write_unit(weight_waddr, weight_w, W_inj, b_inj, prelu_param, gating_params, W_out, b_out,W_ir ,W_hr, W_iz, W_hz, W_in, W_hn, b_ir, b_hr, b_iz, b_hz, b_in, b_hn);


    // Call core function
    ResGRU(
        IQ_seq,
        OUT_seq,
        W_inj, b_inj,
        prelu_param, gating_params,
        W_ir, W_hr, W_iz, W_hz, W_in, W_hn,
        b_ir, b_hr, b_iz, b_hz, b_in, b_hn,
        W_out, b_out
    );

    // Read output sample
    IQ_r_0 = OUT_seq[IQ_r_address][0];
    IQ_r_1 = OUT_seq[IQ_r_address][1];
}
