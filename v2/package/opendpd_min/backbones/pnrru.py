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
'''
class PNRRULAYER(jit.ScriptModule):
    def __init__(self, input_size, hidden_size, num_layers, bidirectional=False, batch_first=True, bias=True):
        super(PNRRULAYER, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = input_size
        self.num_layers = num_layers
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias
        self.half_hidden_size = int(hidden_size/2)

        self.W_x = nn.Linear(self.input_size, self.hidden_size, bias=bias)


        layers = []
        for i in range(num_layers):
            curr_input_size = self.input_size if i == 0 else hidden_size
            layers.append(RRUCell(curr_input_size, hidden_size))
        self.layers = nn.ModuleList(layers)

    @jit.script_method
    def forward(self, x: torch.Tensor, h_0, r_k) -> torch.Tensor:
        if self.batch_first:
            # x : (batch, seq_len, hidden_size) -> (seq_len, batch, hidden_size)
            x = x.transpose(0, 1)
        batch_size = x.size(1)
        seq_len = x.size(0)
        h_real, h_imag = h_0.real,h_0.imag
        h_concat = torch.cat([h_real, h_imag], dim=-1)
        h_t_list = [h_concat]
        for _ in range(self.num_layers-1):
            h_t_list.append(torch.zeros(batch_size, self.hidden_size, device=x.device))

        inputs = x.unbind(0)
        outputs = []  # 여기 추가
        r_prev = torch.ones(batch_size, dtype=torch.complex64, device=x.device)
        for t in range(seq_len):
            input_t = inputs[t]
            h_t = h_t_list[0]
            h_t = torch.complex(
                h_t[..., :self.half_hidden_size],
                h_t[..., self.half_hidden_size:]
            )  # (batch, seq_len, hidden_size)
            if t>0:
                delta = r_k[:,t] * torch.conj(r_prev)
                delta = delta.unsqueeze(-1)
                h_t = h_t * delta
            # Process entire sequence at once
            h_real, h_imag = h_t.real, h_t.imag  # (batch, hidden_size)
            h_concat = torch.cat([h_real, h_imag], dim=-1)

            h_t[0] = h_concat.squeeze(0)  # (batch, 2*hidden_size)
            for idx, layer in enumerate(self.layers):
                h_t, _ = layer(input_t, h_t_list[idx])
                h_t_list[idx] = h_t
                input_t = h_t
            outputs.append(input_t.unsqueeze(0))  # 시퀀스 차원 추가해서 쌓음
            r_prev = r_k[:, -1]
        out = torch.cat(outputs, dim=0)  # (seq_len, batch, hidden_size)
        return out
 

class PNRRU(nn.Module):
    def __init__(self, hidden_size, output_size, num_layers, bidirectional=False, batch_first=True, bias=True):
        super(PNRRU, self).__init__()
        self.hidden_size = 2* hidden_size
        self.input_size = 6
        self.output_size = output_size
        self.num_layers = num_layers
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias
        self.half_hidden_size = int(self.hidden_size/2)
        self.W_x = nn.Linear(self.input_size, self.hidden_size, bias=bias)
        self.rnn =PNRRULAYER(
                input_size=self.hidden_size,
                hidden_size=self.hidden_size,
                num_layers=self.num_layers,
                bidirectional=bidirectional,
                batch_first=batch_first,
                bias=bias
                )


        self.fc_out_real = nn.Linear(self.half_hidden_size, 1, bias=bias)
        self.fc_out_imag = nn.Linear(self.half_hidden_size, 1, bias=bias)

        self.reset_parameters()

    def reset_parameters(self):
        nn.init.xavier_uniform_(self.W_x.weight)
        if self.bias:
            nn.init.zeros_(self.W_x.bias)
        #self.rnn.reset_parameters()
        nn.init.xavier_uniform_(self.fc_out_real.weight)
        nn.init.xavier_uniform_(self.fc_out_imag.weight)
        if self.bias:
            nn.init.zeros_(self.fc_out_real.bias)
            nn.init.zeros_(self.fc_out_imag.bias)

    def complex_to_IQ(self, complex_signal):
        """
        Convert complex signal to I-Q pairs.
        Args:
            complex_signal: (batch, seq_len) complex tensor
        Returns:
            (batch, seq_len, 2) tensor containing I-Q pairs
        """
        return torch.stack((complex_signal.real, complex_signal.imag), dim=2)
    def forward(self, x, h_0=None):
        if self.batch_first:
            batch_size, _, _ = x.size()
        else:
            x = x.transpose(0, 1)  # (batch, seq_len, features)
            batch_size, _, _ = x.size()
        # Initialize hidden state
        if h_0 is None:
            h_0 = torch.zeros( batch_size, self.half_hidden_size, 
                            dtype=torch.complex64, device=x.device)

        # Preprocess input
        i_x = x[..., 0]  # (batch, seq_len)
        q_x = x[..., 1]  # (batch, seq_len)
        complex_x = torch.complex(i_x, q_x)  # (batch, seq_len)

        r_k = torch.conj(complex_x) / (complex_x.abs() + 1e-8)  # (batch, seq_len)
        x_norm = r_k * complex_x  # (batch, seq_len)

        i_x_norm = x_norm.real.unsqueeze(-1)  # (batch, seq_len, 1)
        q_x_norm = x_norm.imag.unsqueeze(-1)  # (batch, seq_len, 1)

        amp2 = i_x_norm**2 + q_x_norm**2  # (batch, seq_len, 1)
        amp = torch.sqrt(amp2)  # (batch, seq_len, 1)
        amp3 = amp**3  # (batch, seq_len, 1)
        cos = i_x_norm / (amp + 1e-8)  # (batch, seq_len, 1)
        sin = q_x_norm / (amp + 1e-8)  # (batch, seq_len, 1)
        x_features = torch.cat((i_x_norm, q_x_norm, amp, amp3, sin, cos), dim=-1)  # (batch, seq_len, 6)
        out = self.W_x(x_features)  # (batch, seq_len, hidden_size)

        h_t = h_0.squeeze(0)
        if not torch.is_complex(h_t):
            h_t = torch.complex(h_t, torch.zeros_like(h_t))

        h_out = self.rnn(out, h_t, r_k)  # (batch, seq_len, 2*hidden_size)
        if self.batch_first:
            h_out = h_out.permute(1, 0, 2)  # (batch, seq_len, 2*hidden_size)
        h_t = torch.complex(
            h_out[..., :self.half_hidden_size],
            h_out[..., self.half_hidden_size:]
        )  # (batch, seq_len, hidden_size)
        r_prev = r_k[:, -1]  # Update for next layer
        out_real = h_t.real  # (batch, seq_len, hidden_size)
        out_imag = h_t.imag
        # Final output
        out_real = self.fc_out_real(out_real).squeeze(-1)  # (batch, seq_len)
        out_imag = self.fc_out_imag(out_imag).squeeze(-1)  # (batch, seq_len)
        y_complex = torch.complex(out_real, out_imag)  # (batch, seq_len)
        y_complex = torch.conj(r_k) * y_complex  # (batch, seq_len)
        y_out = self.complex_to_IQ(y_complex)  # (batch, seq_len, 2)
        
        return y_out



'''
class PNRRUcell(nn.Module):
    def __init__(self, input_size, hidden_size, output_size, bidirectional=False, batch_first=True, bias=True):
        super(PNRRUcell, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = input_size
        self.output_size = output_size
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias

        self.W_u = nn.Linear(input_size + 2 * hidden_size, 2 * hidden_size, bias=bias)
        self.W_h = nn.Linear(2 * hidden_size, 2 * hidden_size, bias=bias)

        self.C = nn.Parameter(torch.tensor(0.5, dtype=torch.float32))
        self.Z = nn.Parameter(torch.tensor(0.5, dtype=torch.float32))

        self.reset_parameters()

    def reset_parameters(self):
        nn.init.xavier_uniform_(self.W_u.weight)
        nn.init.xavier_uniform_(self.W_h.weight)
        if self.bias:
            nn.init.zeros_(self.W_u.bias)
            nn.init.zeros_(self.W_h.bias)

    def forward(self, x, h_0):
        # x: (batch, seq_len, input_size), h_0: (batch, 2*hidden_size)
        combined = torch.cat((x, h_0), dim=-1)  # (batch, seq_len, input_size + 2*hidden_size)
        u1 = torch.relu(self.W_u(combined))  # (batch, seq_len, 2*hidden_size)
        u2 = torch.relu(self.W_h(u1))  # (batch, seq_len, 2*hidden_size)
        next_h = torch.sigmoid(self.C) * h_0 + self.Z * u2  # (batch, seq_len, 2*hidden_size)

        if torch.isnan(self.C).any():
            raise RuntimeError(f"self.C became NaN during training! Current value: {self.C}")
        if torch.isnan(self.Z).any():
            raise RuntimeError(f"self.Z became NaN during training! Current value: {self.Z}")
        
        return next_h, next_h.unsqueeze(0)  # (batch, seq_len, 2*hidden_size), (1, batch, seq_len, 2*hidden_size)

class PNRRU(nn.Module):
    def __init__(self, hidden_size, output_size, num_layers, bidirectional=False, batch_first=True, bias=True):
        super(PNRRU, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = 6
        self.output_size = output_size
        self.num_layers = num_layers
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias

        self.W_x = nn.Linear(in_features=self.input_size, out_features=self.hidden_size, bias=self.bias)
        self.rnn = nn.ModuleList([
            PNRRUcell(
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
        x_norm = r_k * complex_x

        i_x_norm = x_norm.real.unsqueeze(-1)
        q_x_norm = x_norm.imag.unsqueeze(-1)

        amp2 = i_x_norm**2 + q_x_norm**2
        amp = torch.sqrt(amp2)
        amp3 = amp**3
        cos = i_x_norm / (amp + 1e-8)
        sin = q_x_norm / (amp + 1e-8)
        x_features = torch.cat((i_x_norm, q_x_norm, amp, amp3, sin, cos), dim=-1)
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

class SPNRRU(nn.Module):
    def __init__(self, hidden_size, output_size, num_layers, bidirectional=False, batch_first=True, bias=True):
        super(SPNRRU, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = 2
        self.output_size = output_size
        self.num_layers = num_layers
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias

        self.W_x = nn.Linear(in_features=self.input_size, out_features=self.hidden_size, bias=self.bias)
        self.rnn = nn.ModuleList([
            PNRRUcell(
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
