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

import torch
import torch.nn as nn


class RNNBlock(nn.Module):
    def __init__(self, input_size, hidden_size, rnn_type='GRU',act_type=0):
        super().__init__()
        if rnn_type == 'GRU':
            self.rnn = nn.GRU(input_size, hidden_size, batch_first=True)
        elif rnn_type == 'LSTM':
            self.rnn = nn.LSTM(input_size, hidden_size, batch_first=True)
        else:
            self.rnn = nn.RNN(input_size, hidden_size, batch_first=True)

        self.act = ExtendedActivation(act_type)
    
    def forward(self, x):
        out, _ = self.rnn(x)
        out = self.act(out)
        return out


class ResURNN(nn.Module):
    def __init__(self, input_size, hidden_size, num_layers = 1, rnn_type='GRU',act_type=0):
        super().__init__()
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.encoders = nn.ModuleList([
            RNNBlock(self.input_size, self.hidden_size, rnn_type,act_type=act_type)
            for _ in range(self.num_layers)
        ]) 
        self.bottleneck = RNNBlock(self.hidden_size, self.hidden_size, rnn_type,act_type=act_type)

        self.decoders = nn.ModuleList([
            RNNBlock(2*self.hidden_size, self.hidden_size, rnn_type,act_type=act_type)
            for _ in range(self.num_layers)
        ]) 
        

    def forward(self, x):
        en = x
        skip_connection = []
        for en_layer in self.encoders:
            en = en_layer(en)
            skip_connection.append(en)

        de = self.bottleneck(en)

        for i in reversed(range(self.num_layers)):
            de = torch.cat([de, skip_connection[i]], dim=-1)
            de = self.decoders[i](de)

        return de
