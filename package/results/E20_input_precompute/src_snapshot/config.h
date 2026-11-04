#define I_SIZE 5
#define H_SIZE 5
#define NUM_LAYERS 3
#define TIME_STEP 64
#define FEX_NR_ITERATIONS 4

typedef ap_fixed<16,2, AP_RND, AP_SAT> data_t;
typedef ap_fixed<16,4, AP_RND, AP_SAT> weight_t;
typedef ap_fixed<18,3, AP_RND, AP_SAT> accum_t;

// Keep a 16-bit FEx intermediate word; allocate 5 integer and 11 fractional bits.
typedef ap_fixed<16,5, AP_RND, AP_SAT> fex_inv_t;
