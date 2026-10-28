// LW-ResGRU HLS testbench — 학습된 가중치(export_golden.py 출력)로 ResGRU를 돌려 결과를 파일로 저장
//
// 사용: csim_design -argv "<golden_dir> <n_samples> <out_file> [segment_len]"
//   golden_dir : export_golden.py --out 폴더 (weights/, vectors/ 포함)
//   n_samples  : TIME_STEP의 배수 (기본 7680)
//   out_file   : HLS 출력 저장 경로 (T x 2). 절대경로를 권장 (csim은 solution/csim/build에서 실행됨)
//   segment_len: 은닉 상태를 0으로 리셋하는 간격 (기본 2560 = PyTorch golden과 같은 조건)
//
// -DRESET_ARG (tcl에서는 RESET_ARG=1 환경변수): ResGRU가 마지막 인자로 bool(이번 블록이 구간 시작인지)을
// 받도록 바꾼 경우에 사용합니다. 구간 경계를 다른 방식으로 처리한다면 이 testbench도 그에 맞게 고치세요.

#include <cstdlib>
#ifdef _WIN32
#include <cstdio>
#endif
#include <fstream>
#include <iostream>
#include <string>
#include <iomanip>

#include "multi_gru.h"

static std::string G;

template <typename T>
static void load(const std::string& name, T* dst, int n) {
    std::ifstream f((G + "/weights/" + name + ".txt").c_str());
    if (!f) { std::cerr << "[TB] missing weight file: " << name << ".txt\n"; std::exit(1); }
    for (int i = 0; i < n; i++) {
        double v;
        if (!(f >> v)) { std::cerr << "[TB] too few values in " << name << ".txt\n"; std::exit(1); }
        dst[i] = T(v);
    }
}

static std::string L(int l, const char* s) { return "L" + std::to_string(l) + "_" + s; }

int main(int argc, char** argv) {
#ifdef _WIN32
    if (_setmaxstdio(2048) < 0) {
        std::cerr << "[TB] unable to increase Windows stdio limit\n";
        return 1;
    }
#endif
    G = argc > 1 ? argv[1] : "golden";
    int n_samples = argc > 2 ? std::atoi(argv[2]) : 7680;
    std::string out_path = argc > 3 ? argv[3] : "hls_out.txt";
    int SEG = argc > 4 ? std::atoi(argv[4]) : 2560;
    if (n_samples % TIME_STEP != 0 || SEG % TIME_STEP != 0) {
        std::cerr << "[TB] n_samples and segment_len must be multiples of TIME_STEP\n"; return 1;
    }

    static weight_t W_inj[H_SIZE][6];
    static data_t   b_inj[H_SIZE];
    static weight_t prelu, gating[NUM_LAYERS];
    static weight_t W_ir[NUM_LAYERS][H_SIZE][H_SIZE], W_hr[NUM_LAYERS][H_SIZE][H_SIZE];
    static weight_t W_iz[NUM_LAYERS][H_SIZE][H_SIZE], W_hz[NUM_LAYERS][H_SIZE][H_SIZE];
    static weight_t W_in[NUM_LAYERS][H_SIZE][H_SIZE], W_hn[NUM_LAYERS][H_SIZE][H_SIZE];
    static data_t b_ir[NUM_LAYERS][H_SIZE], b_hr[NUM_LAYERS][H_SIZE];
    static data_t b_iz[NUM_LAYERS][H_SIZE], b_hz[NUM_LAYERS][H_SIZE];
    static data_t b_in[NUM_LAYERS][H_SIZE], b_hn[NUM_LAYERS][H_SIZE];
    static weight_t W_out[2][H_SIZE];
    static data_t   b_out[2];

    load("W_inj", &W_inj[0][0], H_SIZE * 6);
    load("b_inj", b_inj, H_SIZE);
    load("prelu", &prelu, 1);
    load("gating", gating, NUM_LAYERS);          // σ(S_n)이 이미 적용된 값
    for (int l = 0; l < NUM_LAYERS; l++) {
        load(L(l, "W_ir"), &W_ir[l][0][0], H_SIZE * H_SIZE);
        load(L(l, "W_hr"), &W_hr[l][0][0], H_SIZE * H_SIZE);
        load(L(l, "W_iz"), &W_iz[l][0][0], H_SIZE * H_SIZE);
        load(L(l, "W_hz"), &W_hz[l][0][0], H_SIZE * H_SIZE);
        load(L(l, "W_in"), &W_in[l][0][0], H_SIZE * H_SIZE);
        load(L(l, "W_hn"), &W_hn[l][0][0], H_SIZE * H_SIZE);
        load(L(l, "b_ir"), b_ir[l], H_SIZE);
        load(L(l, "b_hr"), b_hr[l], H_SIZE);
        load(L(l, "b_iz"), b_iz[l], H_SIZE);
        load(L(l, "b_hz"), b_hz[l], H_SIZE);
        load(L(l, "b_in"), b_in[l], H_SIZE);
        load(L(l, "b_hn"), b_hn[l], H_SIZE);
    }
    load("W_out", &W_out[0][0], 2 * H_SIZE);
    load("b_out", b_out, 2);

    std::ifstream fin((G + "/vectors/dpd_in.txt").c_str());
    std::ofstream fout(out_path.c_str());
    fout << std::setprecision(12);
    if (!fin || !fout) { std::cerr << "[TB] cannot open input/output file\n"; return 1; }

    static data_t IQ[TIME_STEP][2], OUT[TIME_STEP][2];
    for (int blk = 0; blk < n_samples / TIME_STEP; blk++) {
        for (int t = 0; t < TIME_STEP; t++) {
            double i, q;
            if (!(fin >> i >> q)) { std::cerr << "[TB] input shorter than n_samples\n"; return 1; }
            IQ[t][0] = data_t(i);
            IQ[t][1] = data_t(q);
        }
        ResGRU(IQ, OUT, W_inj, b_inj, prelu, gating,
               W_ir, W_hr, W_iz, W_hz, W_in, W_hn,
               b_ir, b_hr, b_iz, b_hz, b_in, b_hn,
               W_out, b_out
#ifdef RESET_ARG
               , (blk * TIME_STEP) % SEG == 0     // 구간 시작에서만 리셋
#endif
        );
        for (int t = 0; t < TIME_STEP; t++)
            fout << OUT[t][0].to_double() << " " << OUT[t][1].to_double() << "\n";
    }
    std::cout << "[TB] done: " << n_samples << " samples -> " << out_path << std::endl;
    return 0;
}
