"""Export trained parameters for the v4-compatible HLS testbench."""
import argparse
from pathlib import Path
import shutil

import numpy as np
import torch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('checkpoint', type=Path)
    parser.add_argument('out', type=Path)
    args = parser.parse_args()
    state = torch.load(args.checkpoint, map_location='cpu', weights_only=True)
    root = Path(__file__).resolve().parents[2]
    fixture = root / 'v4/result/v4.1/golden/vectors'
    args.out.mkdir(parents=True)
    shutil.copytree(fixture, args.out / 'vectors')
    weights = args.out / 'weights'
    weights.mkdir()

    def write(name, values):
        np.savetxt(weights / f'{name}.txt', values.detach().reshape(-1).numpy(), fmt='%.12g')

    for name, key in [('W_inj', 'W_in.weight'), ('b_inj', 'W_in.bias'),
                      ('W_out', 'fc_out.weight'), ('b_out', 'fc_out.bias'),
                      ('prelu', 'in_act.alpha')]:
        write(name, state[f'backbone.{key}'])
    write('gating', torch.cat([state[f'backbone.rnn.gates.{i}'] for i in range(3)]).sigmoid())
    for layer in range(3):
        prefix = f'backbone.rnn.rnn_layers.{layer}.'
        for filename, key in [('W_i', 'weight_ih_l0'), ('W_h', 'weight_hh_l0'),
                              ('b_i', 'bias_ih_l0'), ('b_h', 'bias_hh_l0')]:
            if prefix + 'weight_hn' in state:
                if key == 'weight_hh_l0':
                    candidate = state[prefix + 'weight_hn']
                    packed = torch.cat((torch.zeros_like(candidate), torch.zeros_like(candidate), candidate))
                else:
                    packed = state[prefix + key.removesuffix('_l0')]
            else:
                packed = state[prefix + key]
            if packed.shape[0] == 10:
                z, n = packed.chunk(2)
                gates = (torch.zeros_like(z), z, n)
            elif packed.shape[0] == 15:
                gates = packed.chunk(3)
            else:
                raise ValueError(f'Unexpected gate layout in {prefix + key}')
            for gate, values in zip('rzn', gates):
                write(f'L{layer}_{filename}{gate}', values)


if __name__ == '__main__':
    main()
