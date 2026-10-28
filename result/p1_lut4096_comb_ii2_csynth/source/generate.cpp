#include <iostream>
#include "ap_fixed.h"
#include "src/config.h"
#include "src/activations.h"
struct config_a : nnet::activ_config { static const unsigned table_size=4096; typedef data_t table_t; };
int main(){ data_t s[4096],t[4096]; nnet::init_sigmoid_table<config_a,4096>(s); nnet::init_tanh_table<config_a,4096>(t); for (int i=0;i<4096;i++) {ap_int<16> x; x.range(15,0)=s[i].range(15,0); std::cout<<x.to_int()<<"\n";} for (int i=0;i<4096;i++) {ap_int<16> x; x.range(15,0)=t[i].range(15,0); std::cout<<x.to_int()<<"\n";} }

