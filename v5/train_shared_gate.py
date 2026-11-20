"""Fine-tune a GRU with r=z in selected layers using the frozen PA model."""
import argparse
import copy
import json
import os
from pathlib import Path
import subprocess
import sys

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / 'v1/tools'
DATA = ROOT / 'v1/opendpd_min'


class SharedGateGRU(nn.Module):
    def __init__(self, source):
        super().__init__()
        for name in ('weight_ih_l0', 'weight_hh_l0', 'bias_ih_l0', 'bias_hh_l0'):
            _, update, candidate = getattr(source, name).detach().chunk(3)
            setattr(self, name, nn.Parameter(torch.cat((update, candidate))))

    def forward(self, x):
        w_z, w_n = self.weight_hh_l0.chunk(2)
        b_z, b_n = self.bias_hh_l0.chunk(2)
        hidden = x.new_zeros(x.shape[0], w_z.shape[0])
        result = []
        projected = F.linear(x, self.weight_ih_l0, self.bias_ih_l0)
        for step in projected.unbind(dim=1):
            x_z, x_n = step.chunk(2, dim=-1)
            z = torch.sigmoid(x_z + F.linear(hidden, w_z, b_z))
            n = torch.tanh(x_n + z * F.linear(hidden, w_n, b_n))
            hidden = n + z * (hidden - n)
            result.append(hidden)
        return torch.stack(result, dim=1), hidden.unsqueeze(0)


def protect_zero(iq):
    offset = (iq == 0).all(dim=-1) * 1e-9
    return iq + torch.stack((offset, torch.zeros_like(offset)), dim=-1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=['layer2', 'all'], required=True)
    parser.add_argument('--epochs', type=int, default=100)
    stopping = parser.add_mutually_exclusive_group()
    stopping.add_argument('--early-stop', action='store_true', help='Stop after five epochs without validation improvement.')
    stopping.add_argument('--no-early-stop', dest='early_stop', action='store_false')
    parser.set_defaults(early_stop=False)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    if args.epochs < 0 or out.exists():
        parser.error('Choose a new output directory and a nonnegative epoch count.')
    os.chdir(DATA)
    sys.path.insert(0, str(TOOLS))
    from eval_pa import load_dataset, models, set_target_gain

    torch.set_num_threads(2)
    torch.manual_seed(4574)
    dpd = models.CoreModel(2, 5, 3, 'rgruwfex', residual_type=2)
    pa = models.CoreModel(2, 8, 1, 'dgru')
    checkpoints = {}
    for model, stage in [(dpd, 'train_dpd'), (pa, 'train_pa')]:
        checkpoint, = (Path('save/DPA_200MHz') / stage).glob('*.pt')
        model.load_state_dict(torch.load(checkpoint, map_location='cpu', weights_only=True))
        model.eval()
        checkpoints[stage] = checkpoint
    pa.requires_grad_(False)
    baseline = copy.deepcopy(dpd).requires_grad_(False)
    layers = [1] if args.scope == 'layer2' else [0, 1, 2]
    for index in layers:
        gru = dpd.backbone.rnn.rnn_layers[index]
        dpd.backbone.rnn.rnn_layers[index] = SharedGateGRU(gru)

    train_x, train_y, val_x, _, test_x, _ = load_dataset('DPA_200MHz')
    gain = float(set_target_gain(train_x, train_y))
    segment = json.loads(Path('datasets/DPA_200MHz/spec.json').read_text())['nperseg']
    train, val, test = [torch.tensor(x, dtype=torch.float32).reshape(-1, segment, 2)
                        for x in (train_x, val_x, test_x)]
    optimizer = torch.optim.Adam(dpd.parameters(), lr=0.00025, foreach=False)

    def loss(model, data):
        target = data * gain
        prediction = pa(protect_zero(model(protect_zero(data))))
        return (prediction - target).square().mean() / target.square().mean()

    best, best_epoch, history = float('inf'), 0, []
    for epoch in range(args.epochs + 1):
        if epoch:
            for index in torch.randperm(len(train)).tolist():
                optimizer.zero_grad()
                loss(dpd, train[index:index + 1]).backward()
                optimizer.step()
        with torch.no_grad():
            score = float(10 * torch.log10(loss(dpd, val)))
        if not np.isfinite(score):
            raise ValueError('Nonfinite validation NMSE')
        history.append(score)
        if score < best:
            best, best_epoch = score, epoch
            best_state = copy.deepcopy(dpd.state_dict())
        print(f'epoch={epoch} val_nmse_db={score:.5f}', flush=True)
        if args.early_stop and epoch - best_epoch >= 5:
            break

    out.mkdir(parents=True)
    dpd.load_state_dict(best_state)
    torch.save(best_state, out / 'dpd.pt')
    for name, model in [('baseline', baseline), ('candidate', dpd)]:
        with torch.no_grad():
            values = model(protect_zero(test)).reshape(-1, 2).numpy()
        np.savetxt(out / f'{name}.txt', values)
    report = subprocess.run([sys.executable, str(TOOLS / 'eval_pa.py'), '--pa',
                             str(checkpoints['train_pa']), str(out / 'baseline.txt'),
                             str(out / 'candidate.txt')], capture_output=True,
                            text=True, encoding='utf-8', check=True,
                            env={**os.environ, 'PYTHONIOENCODING': 'utf-8'})
    (out / 'evaluation.txt').write_text(report.stdout, encoding='utf-8')
    summary = dict(scope=args.scope, shared_layers=[i + 1 for i in layers],
                   best_epoch=best_epoch, validation_nmse_db=history, seed=4574)
    (out / 'validation.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(report.stdout)


if __name__ == '__main__':
    main()
