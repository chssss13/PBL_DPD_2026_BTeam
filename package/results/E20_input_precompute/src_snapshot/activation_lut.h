#pragma once
#include "activation_lut_pairs.h"
namespace nnet {
// Same Q14 nodes and AP_RND interpolation as E10. Fetch base and slope
// together, and keep only fraction bits actually present in the input.
template<typename in_T, typename out_T>
void interpolate_activation_pair(in_T in, const ap_uint<26> (&table)[1024],
                                 bool sigmoid, out_T &out) {
#pragma HLS INLINE
    if (in <= -16) { out = sigmoid ? out_T(0) : out_T(-1); return; }
    if (in >= 16) { out = out_T(1); return; }
    const int FRAC = in_T::width - in_T::iwidth - 5;
    static_assert(FRAC > 0, "Activation input must retain sub-grid bits");
    ap_ufixed<10+FRAC,10> position = (in + 16) * 32;
    ap_uint<10> index = position.range(9+FRAC, FRAC);
    ap_uint<FRAC> fraction = position.range(FRAC-1,0);
    ap_uint<26> entry = table[index];
    ap_int<16> base = entry.range(15,0);
    ap_uint<10> slope = entry.range(25,16);
    ap_uint<FRAC+10> product = fraction * slope;
#pragma HLS BIND_OP variable=product op=mul impl=fabric latency=0
    ap_uint<FRAC+11> rounded = ap_uint<FRAC+11>(product) + (1 << (FRAC-1));
    ap_int<17> code = ap_int<17>(base) + ap_int<17>(rounded >> FRAC);
    // Monotone interpolation of Q14 sigmoid/tanh nodes is in [-1,1].
    // Write that proven range directly without a redundant saturating cast.
    static_assert(out_T::width==16 && out_T::iwidth==2, "Expected Q14 output");
    out.range(15,0) = code.range(15,0);
}
template<typename in_T, typename out_T>
void sigmoid_lut(in_T in, out_T &out) {
#pragma HLS INLINE
#pragma HLS BIND_STORAGE variable=sigmoid_pairs type=rom_np impl=lutram latency=1
    interpolate_activation_pair(in, sigmoid_pairs, true, out);
}
template<typename in_T, typename out_T>
void tanh_lut(in_T in, out_T &out) {
#pragma HLS INLINE
#pragma HLS BIND_STORAGE variable=tanh_pairs type=rom_np impl=lutram latency=1
    interpolate_activation_pair(in, tanh_pairs, false, out);
}
}

