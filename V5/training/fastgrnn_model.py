"""Floating-point training form of v4.6_fastgrnn_outpipe (H=5, L=3).

Pipeline identity registers do not change sample-domain model equations.
This module does not claim to simulate HLS rounding, saturation or LUTs.
"""
from typing import List
import math

import torch
from torch import nn
from torch.nn import functional as F


@torch.jit.script
def recurrent_sequence(x: torch.Tensor, W: torch.Tensor, U: torch.Tensor,
                       bz: torch.Tensor, bh: torch.Tensor,
                       zeta: torch.Tensor, nu: torch.Tensor) -> torch.Tensor:
    # Wx is independent of h and can be computed for the full sequence.
    projected = F.linear(x, W)
    h = torch.zeros((x.size(0), U.size(0)), dtype=x.dtype, device=x.device)
    states = torch.jit.annotate(List[torch.Tensor], [])
    for t in range(x.size(1)):
        shared = projected[:, t] + F.linear(h, U)
        z = torch.sigmoid(shared + bz)
        n = torch.tanh(shared + bh)
        # Match the rearranged HLS update; residual is NOT stored as state.
        q = zeta * n
        r = nu * n
        h = q + r + z * (h - q)
        states.append(h)
    return torch.stack(states, dim=1)


class FastGRNNDPD(nn.Module):
    def __init__(self):
        super().__init__()
        self.W_in = nn.Linear(6, 5)
        self.prelu = nn.Parameter(torch.tensor(0.25))
        self.W = nn.Parameter(torch.empty(3, 5, 5))
        self.U = nn.Parameter(torch.empty(3, 5, 5))
        self.b_z = nn.Parameter(torch.zeros(3, 5))
        self.b_h = nn.Parameter(torch.zeros(3, 5))
        self.zeta_logits = nn.Parameter(torch.full((3,), math.log(0.75 / 0.25)))
        self.nu_logits = nn.Parameter(torch.full((3,), math.log(0.125 / 0.875)))
        self.gate_logits = nn.Parameter(torch.full((3,), 0.5))
        self.fc_out = nn.Linear(5, 2)
        for layer in range(3):
            nn.init.xavier_uniform_(self.W[layer])
            nn.init.orthogonal_(self.U[layer])
        nn.init.xavier_uniform_(self.W_in.weight)
        nn.init.zeros_(self.W_in.bias)
        nn.init.xavier_uniform_(self.fc_out.weight)
        nn.init.zeros_(self.fc_out.bias)
        assert sum(p.numel() for p in self.parameters()) == 237

    def hidden_features(self, iq):
        i, q = iq[..., :1], iq[..., 1:]
        amp2 = i.square() + q.square()
        amp = torch.sqrt(amp2)
        # Same feature order as v4.6 and current HLS, with a zero guard.
        denominator = amp.clamp_min(1e-12)
        features = torch.cat((i, q, amp, amp.pow(3), q / denominator,
                              i / denominator), dim=-1)
        x = F.prelu(self.W_in(features), self.prelu)
        zeta, nu = self.zeta_logits.sigmoid(), self.nu_logits.sigmoid()
        gates = self.gate_logits.sigmoid()
        for layer in range(3):
            h = recurrent_sequence(x, self.W[layer], self.U[layer],
                                   self.b_z[layer], self.b_h[layer],
                                   zeta[layer], nu[layer])
            x = h + gates[layer] * x
        return x

    def forward(self, iq):
        return self.fc_out(self.hidden_features(iq))

    @torch.no_grad()
    def hardware_parameters(self):
        def array(x):
            return x.detach().cpu().tolist()
        return dict(W_inj=array(self.W_in.weight), b_inj=array(self.W_in.bias),
                    prelu=float(self.prelu), gating=array(self.gate_logits.sigmoid()),
                    W=array(self.W), U=array(self.U), b_z=array(self.b_z),
                    b_h=array(self.b_h), zeta=array(self.zeta_logits.sigmoid()),
                    nu=array(self.nu_logits.sigmoid()), W_out=array(self.fc_out.weight),
                    b_out=array(self.fc_out.bias))
