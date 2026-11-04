from torch import nn
import torch


import torch.nn.functional as F
class PreLU(nn.Module):
    def __init__(self):
        super().__init__()
        self.alpha = nn.Parameter(torch.tensor(0.25))
    def forward(self, x):
        return F.prelu(x, self.alpha)

class LW_RESGRU(nn.Module): # conventional RNN layer
    def __init__(self, hidden_size, num_layers, rnn_type='RNN', bias=True):
        super(LW_RESGRU, self).__init__()
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.is_LSTM = False


        rnn_types = {
            'RNN': nn.RNN,
            'GRU': nn.GRU,
            'LSTM': nn.LSTM
        }

        if rnn_type not in rnn_types:
            raise ValueError(f"Unknown rnn_type: {rnn_type}")

        self.is_LSTM = rnn_type == 'LSTM'
        rnn_class = rnn_types[rnn_type]
         
        self.rnn_layers = nn.ModuleList([
            rnn_class(input_size= self.hidden_size,
                       hidden_size=self.hidden_size,
                      num_layers=1, batch_first=True, bias=bias)
            for _ in range(num_layers)
        ]) 
        self.gates = nn.ParameterList([
            nn.Parameter(torch.Tensor(1)) for _ in range(num_layers)
        ])
        self.reset_parameters()

    def reset_parameters(self):
        for rnn in self.rnn_layers:
            for name, param in rnn.named_parameters():
                if 'bias' in name:
                    nn.init.constant_(param, 0)
                elif 'weight' in name:
                    nn.init.orthogonal_(param)

        for gate in self.gates:
            nn.init.constant_(gate, 0.5)  # Start from semi-passthrough
    def forward(self, x, h_0=None):
        
        for i, rnn in enumerate(self.rnn_layers):
            out, _ = rnn(x)

            gate = torch.sigmoid(self.gates[i])

            x = out + gate*x # Residual connection per layer
        out = x
        return out

class ResidualRNNBlock(nn.Module):
    def __init__(self, input_size, hidden_size, output_size,num_layers, rnn_type='GRU', fex=True):
        super().__init__()
        self.hidden_size = hidden_size
        self.fex = fex

        if self.fex:
            self.input_size = 6
        else:
            self.input_size = 2
        #input layer
        self.W_in = nn.Linear(in_features=self.input_size,out_features=self.hidden_size,bias=True)
        

        # flexible RNN type
        self.rnn = LW_RESGRU(hidden_size=hidden_size, num_layers=num_layers,rnn_type=rnn_type)

        self.fc_out = nn.Linear(hidden_size, output_size)
        self.reset_parameters()

    def reset_parameters(self):

        for name, param in self.W_in.named_parameters():
            if 'weight' in name:
                nn.init.xavier_uniform_(param)
            if 'bias' in name:
                nn.init.constant_(param, 0)
        for name, param in self.fc_out.named_parameters():
            if 'weight' in name:
                nn.init.xavier_uniform_(param)
            if 'bias' in name:
                nn.init.constant_(param, 0)
    def forward(self, x, h_0=None):
        if self.fex:
            # Feature Extraction
            i_x = torch.unsqueeze(x[..., 0], dim=-1)
            q_x = torch.unsqueeze(x[..., 1], dim=-1)
            amp2 = torch.pow(i_x, 2) + torch.pow(q_x, 2)
            amp = torch.sqrt(amp2)
            amp3 = torch.pow(amp, 3)
            cos = i_x / amp
            sin = q_x / amp
            x = torch.cat((i_x, q_x, amp, amp3, sin, cos), dim=-1)
        out = self.W_in(x)

        out = torch.relu(out)
        out = self.rnn(out)
        out = self.fc_out(out)
        return out

