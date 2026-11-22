#include "res_fastgrnn.h"
#include "fastgrnn_cell.h"
#include "parameter_io.h"
#include "input_linear_pipeline.h"
#include "output_linear_pipeline.h"
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>

// Separate scalar arithmetic reference. Integer-grid rounding and saturation
// are computed in double; the unchanged v4.6 activation LUTs are shared.
static double q(double x,int bits,int integer) {
    double scale=std::ldexp(1.0,bits-integer);
    double raw=std::floor(x*scale+0.5);
    double lo=-std::ldexp(1.0,bits-1), hi=-lo-1;
    return std::fmax(lo,std::fmin(hi,raw))/scale;
}
static int saturated_updates=0;
static void ref_cell(data_t x[H_SIZE],data_t old[H_SIZE],data_t out[H_SIZE],bool reset,
                     weight_t W[H_SIZE][H_SIZE],weight_t U[H_SIZE][H_SIZE],
                     data_t bz[H_SIZE],data_t bh[H_SIZE],weight_t zeta,weight_t nu) {
    for(int o=0;o<H_SIZE;++o) {
        double wx=0, uh=0;
        for(int i=0;i<H_SIZE;++i) {
            wx+=q(x[i].to_double()*W[o][i].to_double(),18,3);
            uh+=q((reset?0:old[i].to_double())*U[o][i].to_double(),18,3);
        }
        double shared=q(wx,18,3)+q(uh,18,3);
        data_t zpre=q(shared+bz[o].to_double(),15,3), npre=q(shared+bh[o].to_double(),15,3);
        data_t z,n;
        nnet::sigmoid_comb<data_t,data_t,nnet::activ_config>(zpre,z);
        nnet::tanh_comb<data_t,data_t,nnet::activ_config>(npre,n);
        double mix=zeta.to_double()*(1-z.to_double())+nu.to_double();
        double value=mix*n.to_double()+z.to_double()*(reset?0:old[o].to_double());
        if(value < -4 || value > 4-1.0/4096) ++saturated_updates;
        out[o]=q(value,15,3);
    }
}
static uint32_t rng=4574;
static double random_grid(int span,int scale) {
    rng=1664525u*rng+1013904223u;
    return (int(rng%unsigned(2*span+1))-span)/double(scale);
}
static void same(data_t a,data_t b,const char* where) {
    if(a!=b) { std::cerr<<where<<": "<<a<<" != "<<b<<std::endl; std::exit(1); }
}
static void input_linear_regression() {
    data_t x[6],b[H_SIZE]; weight_t w[H_SIZE][6];
    accum_t actual[H_SIZE],original[H_SIZE];
    int clamps=0;
    for(int trial=0;trial<2000;++trial) {
        for(int i=0;i<6;++i) x[i]=random_grid(16384,4096);
        for(int o=0;o<H_SIZE;++o) {
            b[o]=random_grid(16384,4096);
            for(int i=0;i<6;++i) w[o][i]=random_grid(8192,1024);
        }
        InputLinearPipelined(x,w,b,actual);
        Linear<6,H_SIZE,data_t,weight_t,accum_t>(x,w,b,original);
        for(int o=0;o<H_SIZE;++o) {
            double acc=0;
            for(int i=0;i<6;++i) {
                double sum=acc+q(x[i].to_double()*w[o][i].to_double(),18,3);
                acc=q(sum,18,3);
                if(acc!=sum) ++clamps;
            }
            double expected=q(acc+b[o].to_double(),18,3);
            if(actual[o]!=original[o] || actual[o].to_double()!=expected)
                throw std::runtime_error("Input MAC split changed rounding/saturation");
        }
    }
    if(!clamps) throw std::runtime_error("Input MAC saturation not exercised");
    std::cout<<"[TB] 2000 input linear cases PASS; accumulator clamps="<<clamps<<std::endl;
}
static void output_linear_regression() {
    data_t x[H_SIZE],b[2],actual[2]; weight_t w[2][H_SIZE];
    int clamps=0,output_clamps=0;
    for(int trial=0;trial<2000;++trial) {
        for(int i=0;i<H_SIZE;++i) x[i]=random_grid(16384,4096);
        for(int o=0;o<2;++o) {
            b[o]=random_grid(16384,4096);
            for(int i=0;i<H_SIZE;++i) w[o][i]=random_grid(8192,1024);
        }
        OutputLinearPipelined(x,w,b,actual);
        for(int o=0;o<2;++o) {
            output_acc_t original=MAC_PE<H_SIZE,data_t,weight_t,output_acc_t>(x,w[o]);
            data_t old_output=original+b[o];
            double acc=0;
            for(int i=0;i<H_SIZE;++i) {
                double sum=acc+q(x[i].to_double()*w[o][i].to_double(),21,6);
                acc=q(sum,21,6);
                if(acc!=sum) ++clamps;
            }
            double sum=acc+b[o].to_double(),expected=q(sum,15,3);
            if(expected!=sum) ++output_clamps;
            if(actual[o]!=old_output || actual[o].to_double()!=expected)
                throw std::runtime_error("Output MAC register changed rounding/saturation");
        }
    }
    if(!clamps || !output_clamps) throw std::runtime_error("Output saturation not exercised");
    std::cout<<"[TB] 2000 output linear cases PASS; accumulator clamps="<<clamps
             <<"; output clamps="<<output_clamps<<std::endl;
}
static void cell_regression() {
    data_t x[H_SIZE],old[H_SIZE],actual[H_SIZE],expected[H_SIZE];
    weight_t W[H_SIZE][H_SIZE],U[H_SIZE][H_SIZE]; data_t bz[H_SIZE],bh[H_SIZE];
    for(int trial=0;trial<10000;++trial) {
        for(int o=0;o<H_SIZE;++o) {
            x[o]=random_grid(16384,4096); old[o]=random_grid(16384,4096);
            bz[o]=random_grid(16000,4096); bh[o]=random_grid(16000,4096);
            for(int i=0;i<H_SIZE;++i) { W[o][i]=random_grid(8000,1024); U[o][i]=random_grid(8000,1024); }
        }
        weight_t zeta=trial%4==0 ? 0 : trial%4==1 ? 1 : (random_grid(512,1024)+0.5);
        weight_t nu=trial%4==0 ? 0 : trial%4==1 ? 1 : (random_grid(512,1024)+0.5);
        bool reset=trial%7==0;
        FastGRNN_Cell(x,old,actual,reset,W,U,bz,bh,zeta,nu);
        ref_cell(x,old,expected,reset,W,U,bz,bh,zeta,nu);
        for(int o=0;o<H_SIZE;++o) same(actual[o],expected[o],"cell reference");
    }
    if(!saturated_updates) throw std::runtime_error("Saturation edge cases not exercised");
    std::cout<<"[TB] 10000 cell cases PASS; saturated updates="<<saturated_updates<<std::endl;
}
static void reference_block(data_t input[TIME_STEP][2],data_t output[TIME_STEP][2],
                            Parameters& p,data_t state[NUM_LAYERS][H_SIZE],bool reset) {
    for(int t=0;t<TIME_STEP;++t) {
        data_t features[6],x[H_SIZE],next[H_SIZE]; accum_t proj[H_SIZE];
        FExLayer<data_t>(input[t][0],input[t][1],features);
        Linear<6,H_SIZE,data_t,weight_t,accum_t>(features,p.W_inj,p.b_inj,proj);
        nnet::prelu<accum_t,data_t,weight_t,H_SIZE>(proj,x,p.prelu);
        for(int l=0;l<NUM_LAYERS;++l) {
            ref_cell(x,state[l],next,reset && t==0,p.W[l],p.U[l],p.b_z[l],p.b_h[l],p.zeta[l],p.nu[l]);
            for(int i=0;i<H_SIZE;++i) {
                state[l][i]=next[i];
                x[i]=q(next[i].to_double()+p.gates[l].to_double()*x[i].to_double(),15,3);
            }
        }
        for(int o=0;o<2;++o) {
            double acc=0;
            for(int i=0;i<H_SIZE;++i) acc=q(acc+q(x[i].to_double()*p.W_out[o][i].to_double(),21,6),21,6);
            output[t][o]=q(acc+p.b_out[o].to_double(),15,3);
        }
    }
}
static void synthetic(Parameters& p) {
    for(int o=0;o<H_SIZE;++o) {
        p.b_inj[o]=random_grid(32,256);
        for(int i=0;i<6;++i) p.W_inj[o][i]=random_grid(128,256);
    }
    p.prelu=0.25;
    for(int l=0;l<NUM_LAYERS;++l) {
        p.gates[l]=0.5; p.zeta[l]=0.75; p.nu[l]=0.125;
        for(int o=0;o<H_SIZE;++o) {
            p.b_z[l][o]=random_grid(32,256); p.b_h[l][o]=random_grid(32,256);
            for(int i=0;i<H_SIZE;++i) {p.W[l][o][i]=random_grid(96,256);p.U[l][o][i]=random_grid(96,256);}
        }
    }
    for(int o=0;o<2;++o) {p.b_out[o]=random_grid(32,256);for(int i=0;i<H_SIZE;++i)p.W_out[o][i]=random_grid(128,256);}
}
static void top_regression() {
    Parameters p; synthetic(p);
    data_t input[TIME_STEP][2],actual[TIME_STEP][2],expected[TIME_STEP][2],saved[TIME_STEP][2];
    data_t state[NUM_LAYERS][H_SIZE]={};
    for(int t=0;t<TIME_STEP;++t) {input[t][0]=random_grid(1024,4096);input[t][1]=random_grid(1024,4096);}
    for(int call=0;call<6;++call) {
        // Includes continuation, reset replay, and changed matrices/bias/coefs
        // between calls while preserving state. All layers and both W/U change.
        if(call==3) {
            for(int l=0;l<NUM_LAYERS;++l) {
                p.zeta[l]=0.5; p.nu[l]=0.25;
                for(int o=0;o<H_SIZE;++o) {
                    p.b_z[l][o]+=data_t(0.125);p.b_h[l][o]-=data_t(0.0625);
                    for(int i=0;i<H_SIZE;++i) {p.W[l][o][i]=-p.W[l][o][i];p.U[l][o][i]*=weight_t(0.5);}
                }
            }
        }
        bool reset=call==0 || call==2 || call==4;
        run_model(input,actual,p,reset);
        reference_block(input,expected,p,state,reset);
        for(int t=0;t<TIME_STEP;++t) for(int i=0;i<2;++i) {
            same(actual[t][i],expected[t][i],"full model reference");
            if(call==0)saved[t][i]=actual[t][i];
            if(call==2)same(actual[t][i],saved[t][i],"reset replay");
        }
    }
    std::cout<<"[TB] 6 top calls (384 samples), continuation/reset/parameter changes PASS"<<std::endl;
}
int main(int argc,char** argv) {
    try {
#ifdef _WIN32
        _setmaxstdio(2048);
#endif
        input_linear_regression(); output_linear_regression(); cell_regression(); top_regression();
        if(argc>1) {
            if(argc!=6) throw std::runtime_error("Usage: tb params.txt input.txt samples output.txt segment_len");
            Parameters p; load_parameters(argv[1],p);
            int count=std::atoi(argv[3]),segment=std::atoi(argv[5]);
            if(count<=0 || segment<=0 || count%TIME_STEP || segment%TIME_STEP)
                throw std::runtime_error("Positive sample and segment lengths must be multiples of 64");
            std::ifstream f(argv[2]);std::ofstream out(argv[4]);out<<std::setprecision(12);
            if(!f || !out)throw std::runtime_error("Cannot open input/output");
            data_t input[TIME_STEP][2],output[TIME_STEP][2],expected[TIME_STEP][2];
            data_t ref_state[NUM_LAYERS][H_SIZE]={};
            for(int start=0;start<count;start+=TIME_STEP) {
                for(int t=0;t<TIME_STEP;++t) for(int i=0;i<2;++i) {
                    double value;if(!(f>>value) || !std::isfinite(value))throw std::runtime_error("Invalid/short input");
                    input[t][i]=value;
                }
                run_model(input,output,p,start%segment==0);
                reference_block(input,expected,p,ref_state,start%segment==0);
                for(int t=0;t<TIME_STEP;++t)for(int i=0;i<2;++i)
                    same(output[t][i],expected[t][i],"loaded-parameter model reference");
                for(int t=0;t<TIME_STEP;++t)out<<output[t][0].to_double()<<" "<<output[t][1].to_double()<<"\n";
            }
        }
        std::cout<<"[TB] PASS; compact parameter count="<<MODEL_PARAMS<<std::endl;
        return 0;
    }catch(const std::exception& e){std::cerr<<e.what()<<std::endl;return 1;}
}
