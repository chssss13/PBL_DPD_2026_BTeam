__author__ = "Yizhuo Wu, Chang Gao"
__license__ = "Apache-2.0 License"
__email__ = "yizhuo.wu@tudelft.nl, chang.gao@tudelft.nl"

import torch
from torch import nn

import torch.jit as jit
from typing import Tuple, List


import torch
import torch.nn as nn
import torch.jit as jit
from typing import Tuple, List
from .rru import RRUCell 

class CRRUcell(nn.Module):
    def __init__(self, input_size, hidden_size, output_size, bidirectional=False, batch_first=True, bias=True):
        super(CRRUcell, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = input_size
        self.output_size = output_size
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias

        self.W_u = nn.Linear(self.input_size +  2 *self.hidden_size, 2*self.hidden_size, bias=self.bias)
        self.W_h = nn.Linear(2 *self.hidden_size, 2 *self.hidden_size, bias=self.bias)
        self.W_tc_1 = nn.Linear(2 *self.hidden_size, 2 *self.hidden_size, bias=self.bias)
        self.W_tc_2 = nn.Linear(2 *self.hidden_size, 2 *self.hidden_size, bias=self.bias)

        self.C = nn.Parameter(torch.tensor(0.5, dtype=torch.float32))
        self.Z = nn.Parameter(torch.tensor(0.5, dtype=torch.float32))

        self.reset_parameters()

    def reset_parameters(self):
        nn.init.xavier_uniform_(self.W_u.weight)
        nn.init.xavier_uniform_(self.W_h.weight)
        nn.init.xavier_uniform_(self.W_tc_1.weight)
        nn.init.xavier_uniform_(self.W_tc_2.weight)
        if self.bias:
            nn.init.zeros_(self.W_u.bias)
            nn.init.zeros_(self.W_h.bias)
            nn.init.zeros_(self.W_tc_1.bias)
            nn.init.zeros_(self.W_tc_2.bias)

    def forward(self, x, h_0):
        # x: (batch, seq_len, input_size), h_0: (batch, 2*hidden_size)
        combined = torch.cat((x, h_0), dim=-1)  # (batch, seq_len, input_size + 2*hidden_size)
        u1 = torch.relu(self.W_u(combined))  # (batch, seq_len, 2*hidden_size)
        u2 = torch.relu(self.W_h(u1))  # (batch, seq_len, 2*hidden_size)
        h_1 = torch.relu(self.W_tc_1(h_0))
        h_2 = self.W_tc_2(h_1)
        next_h = torch.sigmoid(self.C) * h_2 + self.Z * u2  # (batch, seq_len, 2*hidden_size)

        if torch.isnan(self.C).any():
            raise RuntimeError(f"self.C became NaN during training! Current value: {self.C}")
        if torch.isnan(self.Z).any():
            raise RuntimeError(f"self.Z became NaN during training! Current value: {self.Z}")
        
        return next_h, next_h.unsqueeze(0)  # (batch, seq_len, 2*hidden_size), (1, batch, seq_len, 2*hidden_size)


class CPNRRU(nn.Module):
    def __init__(self, hidden_size, output_size, num_layers, bidirectional=False, batch_first=True, bias=True):
        super(CPNRRU, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = 2
        self.output_size = output_size
        self.num_layers = num_layers
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias

        self.W_x = nn.Linear(in_features=self.input_size, out_features=self.hidden_size, bias=self.bias)
        self.rnn = nn.ModuleList([
            CRRUcell(
                input_size=self.hidden_size,
                hidden_size=self.hidden_size,
                output_size=self.hidden_size,
                bidirectional=bidirectional,
                batch_first=batch_first,
                bias=bias
            ) for _ in range(num_layers)
        ])

        self.fc_out_real = nn.Linear(self.hidden_size, 1, bias=self.bias)
        self.fc_out_imag = nn.Linear(self.hidden_size, 1, bias=self.bias)

        self.reset_parameters()

    def reset_parameters(self):
        for layer in self.rnn:
            layer.reset_parameters()
        for name, param in self.W_x.named_parameters():
            if 'weight' in name:
                nn.init.xavier_uniform_(param)
            if 'bias' in name:
                nn.init.constant_(param, 0)
        for name, param in self.fc_out_real.named_parameters():
            if 'weight' in name:
                nn.init.xavier_uniform_(param)
            if 'bias' in name:
                nn.init.constant_(param, 0)
        for name, param in self.fc_out_imag.named_parameters():
            if 'weight' in name:
                nn.init.xavier_uniform_(param)
            if 'bias' in name:
                nn.init.constant_(param, 0)
    def complex_to_IQ(self, complex_signal):
        import numpy as np
        """
        Convert a 1D array of complex signals into a multi-dimensional array of I-Q pairs. 

        Args:

        Returns:
        - 2D array of shape (#segments, frame_length) containing complex signals.
        """
        I = complex_signal.real
        Q = complex_signal.imag
        return torch.stack((I, Q),dim=2)
    
    def forward(self, x, h_0=None):
        if self.batch_first:
            batch_size, seq_len, _ = x.size()
        else:
            seq_len, batch_size, _ = x.size()

        if h_0 is None:
            h_0 = torch.zeros(self.num_layers, batch_size, self.hidden_size, dtype=torch.complex64, device=x.device)

        i_x = x[..., 0]
        q_x = x[..., 1]
        complex_x = torch.complex(i_x, q_x)

        r_k = torch.conj(complex_x) / (complex_x.abs() + 1e-8)

        amp2 = i_x**2 + q_x**2
        amp = torch.sqrt(amp2)
        amp3 = amp**3
        amp = amp.unsqueeze(-1)
        amp3 = amp3.unsqueeze(-1)
        x_features = torch.cat((amp, amp3), dim=-1)
        
        out = self.W_x(x_features)
        h_n = []
        r_prev = torch.ones(batch_size, dtype=torch.complex64, device=x.device)

        for layer in range(self.num_layers):
            h_t = h_0[layer]
            if not torch.is_complex(h_t):
                h_t = torch.complex(h_t, torch.zeros_like(h_t))
            out_seq = []

            for t in range(seq_len):
                x_t = out[:, t, :]
                if t > 0:
                    delta = r_k[:, t] * torch.conj(r_prev)
                    delta = delta.unsqueeze(-1)
                    if layer == 0:
                        h_t = h_t * delta

                h_real, h_imag = h_t.real, h_t.imag
                h_concat = torch.cat([h_real, h_imag], dim=-1)

                h_out, _ = self.rnn[layer](x_t, h_concat)
                h_t = torch.complex(h_out[:, :self.hidden_size], h_out[:, self.hidden_size:])
                r_prev = r_k[:, t]
                out_seq.append(h_t.real)

            out = torch.stack(out_seq, dim=1)
            h_n.append(h_t)

        out_real = self.fc_out_real(out).squeeze(-1)
        out_imag = self.fc_out_imag(out).squeeze(-1)
        y_complex = torch.complex(out_real, out_imag)
        y_out = torch.conj(r_k) * y_complex
        y_out = self.complex_to_IQ(y_out)
        return y_out#, torch.stack(h_n)
