__author__ = "Yizhuo Wu, Chang Gao"
__license__ = "Apache-2.0 License"
__email__ = "yizhuo.wu@tudelft.nl, chang.gao@tudelft.nl"

import torch
from torch import nn

class DKRRUcell(nn.Module):
    def __init__(self, input_size, hidden_size, output_size, bidirectional=False, batch_first=True, bias=True):
        super(RRUcell, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = input_size
        self.output_size = output_size
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias

        # 
        self.W_x = nn.Linear(in_features=self.input_size, out_features=self.hidden_size, bias=self.bias)
        self.W_h = nn.Linear(in_features=self.hidden_size, out_features=self.hidden_size, bias=self.bias)
        self.W_u1 = nn.Linear(in_features= 2*self.hidden_size, out_features=self.hidden_size, bias=self.bias)
        self.W_u2 = nn.Linear(in_features=self.hidden_size, out_features=self.hidden_size, bias=self.bias)

        # 
        self.C = nn.Parameter(torch.tensor(0.5))
        self.Z = nn.Parameter(torch.tensor(0.5))
        #self.N = nn.Parameter(torch.tensor(3.0))

        self.reset_parameters()

    def reset_parameters(self):
        for layer in [self.W_x, self.W_h, self.W_u1, self.W_u2]:
            for name, param in layer.named_parameters():
                if 'weight' in name:
                    nn.init.xavier_uniform_(param)
                if 'bias' in name:
                    nn.init.constant_(param, 0)

    def forward(self, x, h_0=None):
        batch_size = x.size(0)
        if h_0 is None:
            h_0 = torch.zeros(1, batch_size, self.hidden_size, device=x.device)

        current_h = h_0[0]  # (batch_size, hidden_size)

        x = self.W_x(x)  # (batch_size, hidden_size)
        current_h = self.W_h(current_h)  # (batch_size, hidden_size)

        if x.dim() == 3 and current_h.dim() == 2:  # x가 (batch_size, seq_len, hidden_size)인 경우
            current_h = current_h.unsqueeze(1).expand(-1, x.size(1), -1)  # (batch_size, seq_len, hidden_size)
        elif x.dim() == 2 and current_h.dim() == 2:  # x가 (batch_size, hidden_size)인 경우
            pass 

        input = torch.cat((x, current_h), dim=-1)  # (batch_size, [seq_len,] input_size + hidden_size)
        #input = input / self.N
        out = torch.relu(self.W_u1(input))  # (batch_size, [seq_len,] hidden_size)
        out = torch.relu(self.W_u2(out))    # (batch_size, [seq_len,] hidden_size)

        next_h = out * torch.sigmoid(self.C) + current_h * self.Z  # (batch_size, [seq_len,] hidden_size)

        return out, next_h.unsqueeze(0)  # (1, batch_size, [seq_len,] hidden_size)
    
    
class DKRRU(nn.Module):
    def __init__(self, hidden_size, output_size, num_layers, bidirectional=False, batch_first=True, bias=True):
        super(DKRRU, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = 6
        self.output_size = output_size
        self.num_layers = num_layers
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias

        # RNN 레이어들을 nn.ModuleList로 관리
        self.rnn = nn.ModuleList()
        for layer in range(num_layers):
            input_size = self.input_size if layer == 0 else self.hidden_size
            self.rnn.append(
                DKRRUcell(
                    input_size=input_size,
                    hidden_size=self.hidden_size,
                    output_size=self.hidden_size,
                    bidirectional=bidirectional,
                    batch_first=batch_first,
                    bias=bias
                )
            )

 
        self.fc_out = nn.Linear(in_features=self.hidden_size, out_features=self.output_size, bias=self.bias)

        self.reset_parameters()

    def reset_parameters(self):
        for layer in self.rnn:
            layer.reset_parameters()
        for name, param in self.fc_out.named_parameters():
            if 'weight' in name:
                nn.init.xavier_uniform_(param)
            if 'bias' in name:
                nn.init.constant_(param, 0)

    def forward(self, x, h_0=None):

        if self.batch_first:
            batch_size, seq_len, _ = x.size()
        else:
            seq_len, batch_size, _ = x.size()

        if h_0 is None:
            h_0 = torch.zeros(self.num_layers, batch_size, self.hidden_size, device=x.device)

   
        i_x = torch.unsqueeze(x[..., 0], dim=-1)
        q_x = torch.unsqueeze(x[..., 1], dim=-1)
        amp2 = torch.pow(i_x, 2) + torch.pow(q_x, 2)
        amp = torch.sqrt(amp2)
        amp3 = torch.pow(amp, 3)
        cos = i_x / (amp + 1e-8)  # 분모가 0이 되는 경우 방지
        sin = q_x / (amp + 1e-8)
        x = torch.cat((i_x, q_x, amp, amp3, sin, cos), dim=-1)  # (batch_size, seq_len, 6)

 
        out = x
        h_n = []
        for layer in range(self.num_layers):
            h_init = h_0[layer].unsqueeze(0)  # (1, batch_size, hidden_size)
            out_seq = []
            h_t = h_init
            for t in range(seq_len):
                time_step = out[:, t, :] if self.batch_first else out[t, :, :]
                out_t, h_t = self.rnn[layer](time_step, h_t)
                out_seq.append(out_t)
            out = torch.stack(out_seq, dim=1 if self.batch_first else 0)  # (batch_size, seq_len, hidden_size)
            h_n.append(h_t.squeeze(0))  # (batch_size, hidden_size)

    
        out = self.fc_out(out)  # (batch_size, seq_len, output_size)
        return out, torch.stack(h_n)  # (num_layers, batch_size, hidden_size)
    
    
