#pragma once
#include "ap_fixed.h"
#include "ap_int.h"
namespace seed_rsqrt {
typedef ap_fixed<16,5,AP_RND,AP_SAT> inverse_t;
typedef ap_ufixed<16,1,AP_RND,AP_SAT> normalized_t;
static const ap_int<14> correction[64] = {-250,-738,-1204,-1648,-2071,-2474,-2858,-3222,-3568,-3897,-4209,-4504,-4784,-5048,-5297,-5532,-5752,-5960,-6154,-6335,-6504,-6661,-6807,-6941,-7064,-7177,-7279,-7371,-7453,-7526,-7589,-7643,-7689,-7726,-7754,-7774,-7787,-7791,-7788,-7778,-7760,-7735,-7704,-7666,-7621,-7569,-7512,-7448,-7379,-7303,-7222,-7135,-7043,-6945,-6842,-6734,-6621,-6503,-6380,-6252,-6120,-5983,-5842,-5696};
inline inverse_t evaluate(ap_uint<14> amp2_code) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=correction complete dim=1
    if (amp2_code==0) return inverse_t(0);
    ap_uint<4> msb=0;
    for (int bit=0;bit<14;++bit) {
#pragma HLS UNROLL
        if (amp2_code[bit]) msb=bit;
    }
    ap_uint<16> m_code=ap_uint<16>(amp2_code) << (15-msb);
    ap_uint<6> address=m_code.range(14,9);
    ap_int<19> seed_raw=ap_int<19>(163840)-ap_int<19>(m_code)+ap_int<19>(correction[address]);
    ap_uint<16> seed_code=ap_uint<16>((seed_raw+ap_int<19>(2)) >> 2);
    normalized_t m,y;
    m.range(15,0)=m_code;
    y.range(15,0)=seed_code;
    // One NR step on normalized m; seed is p(m)=5/4-m/4 plus correction.
    y=y*(normalized_t(1.5)-normalized_t(0.5)*m*y*y);
    ap_uint<16> y_code=y.range(15,0);
    ap_uint<3> scale=(ap_uint<5>(13)-msb) >> 1;
    ap_uint<32> product=y_code*ap_uint<16>(46341);
#pragma HLS BIND_OP variable=product op=mul impl=dsp
    ap_uint<32> aligned=msb[0] ? product : ap_uint<32>(ap_uint<32>(y_code) << 16);
    ap_uint<5> right_shift=20-scale;
    ap_uint<33> rounded=ap_uint<33>(aligned)+(ap_uint<33>(1) << (right_shift-1));
    ap_uint<19> code=rounded >> right_shift;
    ap_int<16> clipped=code>32767 ? ap_int<16>(32767) : ap_int<16>(code);
    inverse_t result;
    result.range(15,0)=clipped.range(15,0);
    return result;
}
}
