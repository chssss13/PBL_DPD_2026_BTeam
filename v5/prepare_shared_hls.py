"""Generate the two gate-sharing HLS candidates from the archived v4 precursor."""
import argparse
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scope', choices=['layer2', 'all'])
    args = parser.parse_args()
    out = ROOT / 'v5' / f'prj_shared_{args.scope}'
    shutil.copytree(ROOT / 'v4/result/v4.2/fullrom_fc21/src', out / 'src')
    path = out / 'src/multi_gru.cpp'
    source = path.read_text()
    start = source.index('void GRU_single_presummed(')
    end = source.index('\n}', start) + 2
    shared = source[start:end].replace('GRU_single_presummed', 'GRU_single_shared')
    shared = '\n'.join(line for line in shared.splitlines() if not any(
        token in line for token in ('weight_t W_ir', 'data_t b_ir', 'const ap_fixed<16,4> b_r_sum',
                                    'variable=W_ir_x', 'variable=W_hr_h')))
    shared = shared.replace('W_ir_x[H_SIZE], ', '').replace('W_hr_h[H_SIZE], ', '')
    mvm = shared.index('    GRU_Kernel_PE')
    shared = shared[:mvm] + '''    Experiment_Input_MVM<I_SIZE, H_SIZE, data_t, weight_t, accum_t>(x, W_iz, W_iz_x);
    Experiment_Input_MVM<I_SIZE, H_SIZE, data_t, weight_t, accum_t>(x, W_in, W_in_x);
    Recurrent_Gate_MVM<1, H_SIZE, data_t, weight_t, accum_t>(h_state, W_hz, W_hz_h);
    Recurrent_N_Row_MVM<H_SIZE, data_t, weight_t, accum_t>(h_state, W_hn, W_hn_h);
    for (int i = 0; i < H_SIZE; ++i) {
        #pragma HLS PIPELINE II=1
        data_t z_pre = W_iz_x[i] + W_hz_h[i] + b_z_sum[i];
        data_t z, n;
        nnet::sigmoid_comb<data_t, data_t, config_a>(z_pre, z);
        data_t r_h = z * (W_hn_h[i] + b_hn[i]);
        data_t n_pre = W_in_x[i] + b_in[i] + r_h;
        nnet::tanh_comb<data_t, data_t, config_a>(n_pre, n);
        ap_ufixed<12,0> z_gate;
        z_gate.range(11,0) = z.range(11,0);
        ap_fixed<15,3,AP_RND,AP_WRAP> rounded = n + z_gate * (h_state[i] - n);
        h_next[i].range(14,0) = rounded.range(14,0);
    }
}'''
    call_start = source.index('            GRU_single_presummed(')
    call_end = source.index('            );', call_start) + len('            );')
    call = source[call_start:call_end]
    shared_call = '''            GRU_single_shared(
                layer_in[l], (segment_start && (t==0)), h_state_all[l], layer_out[l],
                W_iz[l], W_hz[l], W_in[l], W_hn[l], b_iz[l], b_hz[l], b_in[l], b_hn[l], b_z_sum[l]
            );'''
    if args.scope == 'layer2':
        shared_call = f'            if (l == 1) {{\n{shared_call}\n            }} else {{\n{call}\n            }}'
        loop_start = source.rfind('        LAYER_LOOP:', 0, call_start)
        source = (source[:loop_start] + source[loop_start:call_start].replace(
            '#pragma HLS PIPELINE', '#pragma HLS UNROLL') + shared_call + source[call_end:])
    else:
        source = source[:call_start] + shared_call + source[call_end:]
    path.write_text(source[:end] + '\n\n' + shared + source[end:])


if __name__ == '__main__':
    main()
