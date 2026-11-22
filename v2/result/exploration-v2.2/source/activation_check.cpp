#include "ap_fixed.h"
#include "config.h"
#include "activations.h"
#include <cstdio>
#include <cstdlib>
namespace {
struct ActivationCheck {
    ActivationCheck() {
        for (int raw=-32768; raw<32768; ++raw) {
            data_t x; ap_int<16> bits=raw; x.range(15,0)=bits.range(15,0);
            for (int kind=0; kind<2; ++kind) {
                int pos=raw+32768, index=pos>>7, frac=pos&127;
                unsigned packed = kind ? activation_interp_tables::tanh[index].to_uint() : activation_interp_tables::sigmoid[index].to_uint();
                int base=packed&65535; if (base>=32768) base-=65536;
                int expected=base+(((packed>>16)*frac+64)>>7);
                data_t y;
                if (kind) nnet::reference_tanh<data_t,data_t>(x,y);
                else nnet::reference_sigmoid<data_t,data_t>(x,y);
                ap_int<16> actual=y.range(15,0);
                if (actual.to_int()!=expected) {
                    std::printf("ACTIVATION FAIL raw=%d kind=%d expected=%d actual=%d\n",raw,kind,expected,actual.to_int());
                    std::exit(1);
                }
            }
        }
        std::puts("ACTIVATION CHECK PASS: all 65536 inputs, both functions");
    }
} activation_check;
}
