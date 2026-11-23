#pragma once
#include "res_fastgrnn.h"
#include <cmath>
#include <fstream>
#include <stdexcept>
#include <string>

// Compact text image, exactly 237 numbers, in top-argument order. This is a
// host/testbench loader, NOT an additional synthesizable parameter-storage copy.
struct Parameters {
    weight_t W_inj[H_SIZE][6]; data_t b_inj[H_SIZE];
    weight_t prelu, gates[NUM_LAYERS];
    weight_t W[NUM_LAYERS][H_SIZE][H_SIZE], U[NUM_LAYERS][H_SIZE][H_SIZE];
    data_t b_z[NUM_LAYERS][H_SIZE], b_h[NUM_LAYERS][H_SIZE];
    weight_t zeta[NUM_LAYERS], nu[NUM_LAYERS];
    weight_t W_out[2][H_SIZE]; data_t b_out[2];
};

template<typename T> void read_parameter(std::istream& f, T& value, bool unit=false) {
    double x;
    if (!(f>>x) || !std::isfinite(x)) throw std::runtime_error("Missing/nonfinite parameter");
    const double lo=-(1 << (T::iwidth-1));
    const double hi=-lo-std::ldexp(1.0,-(T::width-T::iwidth));
    if (x<lo || x>hi || (unit && (x<0 || x>1)))
        throw std::runtime_error("Parameter outside fixed-point/coefficient range");
    value=T(x);
}

inline void load_parameters(const std::string& path, Parameters& p) {
    std::ifstream f(path.c_str());
    if (!f) throw std::runtime_error("Cannot open compact parameter image: "+path);
    for(int o=0;o<H_SIZE;++o) for(int i=0;i<6;++i) read_parameter(f,p.W_inj[o][i]);
    for(int i=0;i<H_SIZE;++i) read_parameter(f,p.b_inj[i]);
    read_parameter(f,p.prelu);
    for(int l=0;l<NUM_LAYERS;++l) read_parameter(f,p.gates[l],true);
    for(int l=0;l<NUM_LAYERS;++l) for(int o=0;o<H_SIZE;++o) for(int i=0;i<H_SIZE;++i) read_parameter(f,p.W[l][o][i]);
    for(int l=0;l<NUM_LAYERS;++l) for(int o=0;o<H_SIZE;++o) for(int i=0;i<H_SIZE;++i) read_parameter(f,p.U[l][o][i]);
    for(int l=0;l<NUM_LAYERS;++l) for(int i=0;i<H_SIZE;++i) read_parameter(f,p.b_z[l][i]);
    for(int l=0;l<NUM_LAYERS;++l) for(int i=0;i<H_SIZE;++i) read_parameter(f,p.b_h[l][i]);
    for(int l=0;l<NUM_LAYERS;++l) read_parameter(f,p.zeta[l],true);
    for(int l=0;l<NUM_LAYERS;++l) read_parameter(f,p.nu[l],true);
    for(int o=0;o<2;++o) for(int i=0;i<H_SIZE;++i) read_parameter(f,p.W_out[o][i]);
    for(int i=0;i<2;++i) read_parameter(f,p.b_out[i]);
    std::string extra;
    if(f>>extra) throw std::runtime_error("Expected exactly 237 parameters");
}

inline void run_model(data_t in[TIME_STEP][2], data_t out[TIME_STEP][2], Parameters& p, bool reset) {
    ResFastGRNN(in,out,p.W_inj,p.b_inj,p.prelu,p.gates,p.W,p.U,p.b_z,p.b_h,
               p.zeta,p.nu,p.W_out,p.b_out,reset);
}
