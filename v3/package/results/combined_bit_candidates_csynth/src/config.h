#define I_SIZE 5
#define H_SIZE 5
#define NUM_LAYERS 3
#define TIME_STEP 64

typedef ap_fixed<15,3, AP_RND, AP_SAT> data_t;
typedef ap_fixed<14,4, AP_RND, AP_SAT> weight_t;
typedef ap_fixed<18,3, AP_RND, AP_SAT> accum_t;

// Combined bit-width experiment; external I/Q and biases remain data_t.
typedef ap_fixed<13,1,AP_RND,AP_SAT> state_t;
typedef ap_ufixed<10,0,AP_RND,AP_SAT> residual_t;
typedef ap_fixed<12,2,AP_RND,AP_SAT> inj_weight_t;
typedef ap_fixed<11,1,AP_RND,AP_SAT> out_weight_t;
typedef ap_ufixed<11,1,AP_RND,AP_SAT> prelu_weight_t;
typedef ap_fixed<11,1,AP_RND,AP_SAT> win_weight_t;
typedef ap_fixed<12,2,AP_RND,AP_SAT> whn_weight_t;
typedef ap_fixed<13,3,AP_RND,AP_SAT> whrz_weight_t;
