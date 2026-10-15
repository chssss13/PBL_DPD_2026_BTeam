from torch import nn
import torch


import torch.nn.functional as F
class ExtendedActivation(nn.Module):
    def __init__(self, degree=3):
        super().__init__()
        self.degree = degree
        self.name = ''
        if self.degree > 0:
            self.coeffs = nn.Parameter(torch.randn(degree + 1))
        elif self.degree == 0:  # Trainable Softplus
            self.k = nn.Parameter(torch.tensor(1.0))
        elif self.degree == -4:  # Squared ReLU
            self.coeff = nn.Parameter(torch.tensor(1.0))
        
        elif self.degree == -3:  # Rational activation
            self.p_coeffs = nn.Parameter(torch.randn(4))
            self.q_coeffs = nn.Parameter(torch.randn(4))

        elif self.degree == -5:  # no
            pass
        elif self.degree == -6: # relu
            pass
        elif self.degree == -7:  # PReLU or LeakyReLU
            self.alpha = nn.Parameter(torch.tensor(0.25))
        elif self.degree == -8:  # Trainable Swish
            self.beta = nn.Parameter(torch.tensor(1.0))
        elif self.degree == -9: # swish
            pass
    def print_act(self):
        return self.coeffs.detach().tolist()
    
    def find_name(self):
        if self.degree > 0:
            self.name = f"POLY_{self.degree}"
        elif self.degree == 0:  # Trainable Softplus
            self.name = f"t_softplus_{self.k}"
        elif self.degree == -1:
            self.name = 'sigmoid'
        elif self.degree == -2:
            self.name = 'tanh'
        elif self.degree == -3:  # Rational activation
            self.name = f'rational {self.p_coeffs}/{self.q_coeffs}'
        elif self.degree == -4:  # Squared ReLU
            self.name = f'squared_relu_{self.coeff}'
        elif self.degree == -5:  # no
            self.name = 'no'
        elif self.degree == -6: # relu
            self.name = 'relu'
        elif self.degree == -7:  # PReLU
            self.name = f'Prelu_{self.alpha}'
        elif self.degree == -8:  # Trainable Swish
            self.name = f't_swish_{self.beta}'
        elif self.degree == -9: # swish
            self.name = 'swish'
        return self.name

    def forward(self, x):
        if self.degree > 0:
            out = torch.zeros_like(x)
            for i in range(self.degree + 1):
                out += self.coeffs[i] * torch.pow(x, i)
            return out
        elif self.degree == 0:
            return torch.log(1 + torch.exp(self.k * x)) / self.k
        elif self.degree == -1:
            return torch.sigmoid(x)
        elif self.degree == -2:
            return torch.tanh(x)
        elif self.degree == -3:
            num = sum([self.p_coeffs[i] * x ** i for i in range(4)])
            den = 1 + torch.abs(sum([self.q_coeffs[i] * x ** i for i in range(4)]))
            return num / den
        elif self.degree == -4:
            return self.coeff * torch.pow(F.relu(x), 2)
        elif self.degree == -5: # no
            return x
        elif self.degree == -6: # relu
            return torch.relu(x)
        elif self.degree == -7: # prelu
            return F.prelu(x, self.alpha)
        elif self.degree == -8: #trainable swish
            return x * torch.sigmoid(self.beta * x)
        elif self.degree == -9: #swish
            return x * torch.sigmoid(x)
        else:
            raise ValueError(f"Unsupported activation mode: {self.degree}")


class DGRU(nn.Module):
    def __init__(self,input_size, hidden_size, output_size, num_layers, bidirectional=False, batch_first=True,
                 bias=True):
        super(DGRU, self).__init__()
        self.hidden_size = hidden_size
        self.input_size = input_size
        self.output_size = output_size
        self.num_layers = num_layers
        self.bidirectional = bidirectional
        self.batch_first = batch_first
        self.bias = bias

        # Instantiate NN Layers
        self.rnn = nn.GRU(input_size=self.input_size,
                          hidden_size=hidden_size,
                          num_layers=num_layers,
                          bidirectional=self.bidirectional,
                          batch_first=self.batch_first,
                          bias=self.bias)
        self.fc_out = nn.Linear(in_features=hidden_size + self.input_size,
                                out_features=self.output_size,
                                bias=self.bias)
        self.fc_hid = nn.Linear(in_features=hidden_size,
                                out_features=hidden_size,
                                bias=self.bias)

    def reset_parameters(self):
        for name, param in self.rnn.named_parameters():
            num_gates = int(param.shape[0] / self.hidden_size)
            if 'bias' in name:
                nn.init.constant_(param, 0)
            if 'weight' in name:
                for i in range(0, num_gates):
                    nn.init.orthogonal_(param[i * self.hidden_size:(i + 1) * self.hidden_size, :])
            if 'weight_ih_l0' in name:
                for i in range(0, num_gates):
                    nn.init.xavier_uniform_(param[i * self.hidden_size:(i + 1) * self.hidden_size, :])

        for name, param in self.fc_out.named_parameters():
            if 'weight' in name:
                nn.init.xavier_uniform_(param)
            if 'bias' in name:
                nn.init.constant_(param, 0)

        for name, param in self.fc_hid.named_parameters():
            if 'weight' in name:
                nn.init.kaiming_uniform_(param)
            if 'bias' in name:
                nn.init.constant_(param, 0)

    def forward(self, x, h_0):
        # Regressor
        out, _ = self.rnn(x, h_0)
        out = torch.relu(self.fc_hid(out))
        out = torch.cat((out, x), dim=-1)
        out = self.fc_out(out)
        return out

class RNNWACT(nn.Module): #proposed residual RNN
    def __init__(self, hidden_size, num_layers, rnn_type='RNN', bias=True, act_type = 0 ):
        super(RNNWACT, self).__init__()
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.is_LSTM = False

        
        '''
        self.activations = nn.ModuleList([
            ExtendedActivation(degree=act_type) for _ in range(num_layers)
        ])
        '''
        rnn_types = {
            'RNN': nn.RNN,
            'GRU': nn.GRU,
            'LSTM': nn.LSTM,
            'DGRU': DGRU  # define separately if needed
        }

        if rnn_type not in rnn_types:
            raise ValueError(f"Unknown rnn_type: {rnn_type}")

        self.is_LSTM = rnn_type == 'LSTM'
        rnn_class = rnn_types[rnn_type]
         
        self.rnn_layers =  rnn_class( input_size= self.hidden_size,
                                    hidden_size=self.hidden_size,
                                    num_layers=num_layers,
                                    batch_first=True,
                                    bias=bias)

    def reset_parameters(self):
        for rnn in self.rnn_layers:
            for name, param in rnn.named_parameters():
                if 'bias' in name:
                    nn.init.constant_(param, 0)
                elif 'weight' in name:
                    nn.init.orthogonal_(param)
    def find_name(self):
        return self.activations[0].find_name()

    def forward(self, x, h_0=None):

        out, _ = self.rnn_layers(x) 

        return out

class PRRNN(nn.Module): #proposed residual RNN
    def __init__(self, hidden_size, num_layers, rnn_type='RNN', bias=True, act_type = 0 ):
        super(PRRNN, self).__init__()
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.is_LSTM = False

        
        
        self.activations = nn.ModuleList([
            ExtendedActivation(degree=act_type) for _ in range(num_layers)
        ])

        rnn_types = {
            'RNN': nn.RNN,
            'GRU': nn.GRU,
            'LSTM': nn.LSTM,
            'DGRU': DGRU,  # define separately if needed
            'SRNN' : SwishRNN
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
        # Learnable gating parameters per layer (scalar or tensor)
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
    
    def find_name(self):
        return self.activations[0].find_name()

    def forward(self, x, h_0=None):
        out = x
        
        for i, rnn in enumerate(self.rnn_layers):
            out, _ = rnn(out) 

            gate = torch.sigmoid(self.gates[i])  # scalar gating
            out = out + gate * x 
            if gate< 0.01:
                print("Warning!!!")

            #out = self.activations[i](out)  # For next layer's input
        
        return out

class CRRNN(nn.Module): # conventional RNN layer
    def __init__(self, hidden_size, num_layers, rnn_type='RNN', bias=True, act_type = 0 ):
        super(CRRNN, self).__init__()
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.is_LSTM = False


        rnn_types = {
            'RNN': nn.RNN,
            'GRU': nn.GRU,
            'LSTM': nn.LSTM,
            'DGRU': DGRU,  # define separately if needed
            'SRNN' : SwishRNN
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


class SimpleRNNBlock(nn.Module):
    def __init__(self, input_size, hidden_size, output_size,num_layers, rnn_type='GRU', fex=True):
        super().__init__()
        self.hidden_size = hidden_size
        self.is_LSTM = False
        self.fex = fex
        self.rnn_type = rnn_type
        if self.fex:
            self.input_size = 6
        else:
            self.input_size = 2

        # flexible RNN type
        if rnn_type == 'GRU':
            self.rnn = nn.GRU(input_size= self.input_size,
                              hidden_size=hidden_size,num_layers=num_layers, batch_first=True)
        elif rnn_type == 'LSTM':
            self.rnn = nn.LSTM(input_size= self.input_size,
                                hidden_size=hidden_size,num_layers=num_layers, batch_first=True)
        elif rnn_type == 'RNN':
            self.rnn = nn.RNN(input_size= self.input_size,
                               hidden_size=hidden_size,num_layers=num_layers, batch_first=True)
        elif rnn_type == 'DGRU':
            self.rnn = DGRU(input_size=self.input_size,
                            hidden_size=hidden_size,
                            output_size=hidden_size,
                            num_layers=num_layers)  
        else:
            raise ValueError(f"Unknown rnn_type: {rnn_type}")
        
        self.fc_out = nn.Linear(hidden_size, output_size)


    def reset_parameters(self):
        for name, param in self.rnn.named_parameters():
            num_gates = int(param.shape[0] / self.hidden_size)
            if 'bias' in name:
                nn.init.constant_(param, 0)
            if 'weight' in name:
                for i in range(0, num_gates):
                    nn.init.orthogonal_(param[i * self.hidden_size:(i + 1) * self.hidden_size, :])
            if 'weight_ih_l0' in name:
                for i in range(0, num_gates):
                    nn.init.xavier_uniform_(param[i * self.hidden_size:(i + 1) * self.hidden_size, :])

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

        if self.is_LSTM:
            out, _ = self.rnn(x)
        else:
            out, _ = self.rnn(x)
        out = self.fc_out(out)
        return out

class ResidualRNNBlock(nn.Module):
    def __init__(self, input_size, hidden_size, output_size,num_layers, rnn_type='GRU', fex=True, act_type = 0, residual_mode = 'proposed'):
        super().__init__()
        self.hidden_size = hidden_size
        self.fex = fex

        if self.fex:
            self.input_size = 6
        else:
            self.input_size = 2
        #input layer
        self.W_in = nn.Linear(in_features=self.input_size,out_features=self.hidden_size,bias=True)
        self.in_act = ExtendedActivation(degree=-7)

        # flexible RNN type
        if residual_mode == 'proposed':
            self.rnn = PRRNN(hidden_size=hidden_size, num_layers=num_layers,rnn_type=rnn_type, act_type = act_type)
        elif residual_mode == 'conventional':
            self.rnn = CRRNN(hidden_size=hidden_size, num_layers=num_layers,rnn_type=rnn_type, act_type = act_type)
        elif residual_mode == 'proposed_resU':
            from backbones.resUrnn import ResURNN
            self.rnn = ResURNN(input_size=hidden_size,hidden_size=hidden_size,num_layers=num_layers,rnn_type=rnn_type,act_type=act_type)
        elif residual_mode == 'no':
            self.rnn = RNNWACT(hidden_size=hidden_size, num_layers=num_layers,rnn_type=rnn_type, act_type = act_type)
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

        out = self.in_act(out)
        out = self.rnn(out)
        out = self.fc_out(out)
        return out



import torch
import torch.nn as nn
import torch.nn.functional as F

class SwishActivation(nn.Module):
    def __init__(self, trainable=True):
        super().__init__()
        self.trainable = trainable
        self.beta = nn.Parameter(torch.tensor(1.0)) if trainable else None

    def forward(self, x):
        if self.trainable:
            return x * torch.sigmoid(self.beta * x)
        else:
            return x * torch.sigmoid(x)

class SwishRNNCell(nn.Module):
    def __init__(self, input_size, hidden_size,num_layers=1, trainable_swish=True):
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size

        self.i2h = nn.Linear(input_size, hidden_size)
        self.h2h = nn.Linear(hidden_size, hidden_size)
        self.activation = SwishActivation(trainable=trainable_swish)
        self.reset_parameter()

    def reset_parameter(self):
        for name, param in self.i2h.named_parameters():
                    if 'weight' in name:
                        nn.init.xavier_uniform_(param)
                    if 'bias' in name:
                        nn.init.constant_(param, 0)
        for name, param in self.h2h.named_parameters():
                    if 'weight' in name:
                        nn.init.xavier_uniform_(param)
                    if 'bias' in name:
                        nn.init.constant_(param, 0)

    def forward(self, input, hidden):
        h = self.i2h(input) + self.h2h(hidden)
        return self.activation(h)

class SwishRNN(nn.Module):
    def __init__(self, input_size, hidden_size, trainable_swish=True):
        super().__init__()
        self.hidden_size = hidden_size

        self.rnn_cells = SwishRNNCell(input_size, hidden_size, trainable_swish)


    def forward(self, x):
        # x: [batch_size, seq_len, input_size]
        batch_size, seq_len, _ = x.size()
        device = x.device
        h = [torch.zeros(batch_size, self.hidden_size, device=device) for _ in range(self.num_layers)]

        outputs = []
        for t in range(seq_len):
            input_t = x[:, t, :]
            h = self.rnn_cells(input_t, h)
            outputs.append(h[-1].unsqueeze(1))
        # concat time steps
        out = torch.cat(outputs, dim=1)  # shape: [batch, seq_len, hidden_size]
        return out