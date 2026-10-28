#include <iostream>
#include "src/gru_cell.h"
int main() {
  int failures=0;
  for (int i=0; i<65536; ++i) {
    data_t in, old_s, new_s, old_t, new_t; in.range(15,0)=i;
    nnet::sigmoid_ele<data_t,data_t,config_a>(in,old_s);
    nnet::sigmoid_comb<data_t,data_t,config_a>(in,new_s);
    nnet::tanh_ele<data_t,data_t,config_a>(in,old_t);
    nnet::tanh_comb<data_t,data_t,config_a>(in,new_t);
    if (old_s != new_s || old_t != new_t) { if (failures<8) std::cout << i << " " << old_s << " " << new_s << " " << old_t << " " << new_t << "\n"; ++failures; }
  }
  std::cout << "mismatches=" << failures << "\n"; return failures ? 1 : 0;
}
