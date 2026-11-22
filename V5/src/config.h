#pragma once
#include "ap_fixed.h"

#define I_SIZE 5
#define H_SIZE 5
#define NUM_LAYERS 3
#define TIME_STEP 64

typedef ap_fixed<15,3,AP_RND,AP_SAT> data_t;
typedef ap_fixed<14,4,AP_RND,AP_SAT> weight_t;
typedef ap_fixed<18,3,AP_RND,AP_SAT> accum_t;

// Native coefficient values after sigmoid, not trainable logits.
// zeta, nu and the layer residual gates must be in [0,1].
static const int FASTGRNN_CELL_PARAMS = 2*H_SIZE*H_SIZE + 2*H_SIZE + 2;
static const int MODEL_PARAMS = H_SIZE*6 + H_SIZE + 1 + NUM_LAYERS
    + NUM_LAYERS*FASTGRNN_CELL_PARAMS + 2*H_SIZE + 2;
static_assert(MODEL_PARAMS == 237, "Update the parameter contract if dimensions change");
