__author__ = "Yizhuo Wu, Chang Gao"
__license__ = "Apache-2.0 License"
__email__ = "yizhuo.wu@tudelft.nl, chang.gao@tudelft.nl"

import torch
from torch import nn
from typing import Tuple, List
import torch.jit as jit

class RRUCell(jit.ScriptModule):
    def __init__(self, input_size, hidden_size, bias=True):
        super(RRUCell, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = input_size
        self.bias = bias

        self.W_u = nn.Linear(self.input_size +  self.hidden_size, self.hidden_size, bias=self.bias)
        self.W_h = nn.Linear(self.hidden_size, self.hidden_size, bias=self.bias)
        self.W_tc = nn.Linear(self.hidden_size, self.hidden_size, bias=self.bias)
        self.C = nn.Parameter(torch.tensor(0.5, dtype=torch.float32))
        self.Z = nn.Parameter(torch.tensor(0.5, dtype=torch.float32))
        self.N = nn.Parameter(torch.tensor(0.5, dtype=torch.float32))

        self.reset_parameters()

    def reset_parameters(self):
        nn.init.xavier_uniform_(self.W_u.weight)
        nn.init.xavier_uniform_(self.W_h.weight)
        if self.bias:
            nn.init.zeros_(self.W_u.bias)
            nn.init.zeros_(self.W_h.bias)

    @jit.script_method
    def forward(self, x: torch.Tensor, h_0: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        combined = torch.cat((x, h_0), dim=-1)
        u1 = torch.relu(self.W_u(combined))
        u2 = torch.relu(self.W_h(u1))
        h_1 = torch.relu(self.W_tc(h_0))
        next_h = self.Z * u2 + torch.sigmoid(self.C) * h_1 #  torch.sigmoid(self.C) * h_0 +
        return next_h, next_h.unsqueeze(0)


class RRULAYER(jit.ScriptModule):
    def __init__(self, input_size, hidden_size, num_layers, bidirectional=False, batch_first=True, bias=True):
        super(RRULAYER, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = input_size
        self.num_layers = num_layers
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias

        layers = []
        for i in range(num_layers):
            curr_input_size = self.input_size if i == 0 else hidden_size
            layers.append(RRUCell(curr_input_size, hidden_size))
        self.layers = nn.ModuleList(layers)

    @jit.script_method
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        if self.batch_first:
            # x : (batch, seq_len, hidden_size) -> (seq_len, batch, hidden_size)
            x = x.transpose(0, 1)
        batch_size = x.size(1)
        seq_len = x.size(0)
        h_t_list = []
        for _ in range(self.num_layers):
            h_t_list.append(torch.zeros(batch_size, self.hidden_size, device=x.device))

        inputs = x.unbind(0)
        outputs = []  # 여기 추가

        for t in range(seq_len):
            input_t = inputs[t]
            for idx, layer in enumerate(self.layers):
                h_t, _ = layer(input_t, h_t_list[idx])
                h_t_list[idx] = h_t
                input_t = h_t
            outputs.append(input_t.unsqueeze(0))  # 시퀀스 차원 추가해서 쌓음

        out = torch.cat(outputs, dim=0)  # (seq_len, batch, hidden_size)
        return out


class RRU(nn.Module):
    def __init__(self, hidden_size, output_size, num_layers, bidirectional=False, batch_first=True, bias=True):
        super(RRU, self).__init__()
        self.hidden_size = 2* hidden_size
        self.input_size = 6
        self.output_size = output_size
        self.num_layers = num_layers
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias
        self.half_hidden_size = hidden_size
        self.W_x = nn.Linear(self.input_size, self.hidden_size, bias=bias)
        self.rnn =RRULAYER(
                input_size=self.hidden_size,
                hidden_size=self.hidden_size,
                num_layers=self.num_layers,
                bidirectional=bidirectional,
                batch_first=batch_first,
                bias=bias
                )


        self.fc_out = nn.Linear(self.hidden_size, output_size, bias=bias)

        self.reset_parameters()

    def reset_parameters(self):
        nn.init.xavier_uniform_(self.W_x.weight)
        if self.bias:
            nn.init.zeros_(self.W_x.bias)
        nn.init.xavier_uniform_(self.fc_out.weight)
        if self.bias:
            nn.init.zeros_(self.fc_out.bias)

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
        x_features = torch.cat((i_x.unsqueeze(-1), q_x.unsqueeze(-1), amp, amp3, sin, cos), dim=-1)  # (batch, seq_len, 6)
        out = self.W_x(x_features)  # (batch, seq_len, hidden_size)

        h_out = self.rnn(out)  # (batch, seq_len, 2*hidden_size)
        if self.batch_first:
            h_out = h_out.permute(1, 0, 2)  # (batch, seq_len, 2*hidden_size)

        # Final output
        out = self.fc_out(h_out).squeeze(-1)  # (batch, seq_len)
        
        return out