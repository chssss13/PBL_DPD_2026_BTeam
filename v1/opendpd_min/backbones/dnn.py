"""
Reproduced from: https://ieeexplore.ieee.org/document/9352501
"""

import torch
from torch import nn


class DNN(nn.Module):
    def __init__(self,input_size, num_layer, fc_hid_size=6):
        super(DNN, self).__init__()
        self.fc_hid_size = fc_hid_size
        self.input_size = input_size
        self.num_layer = num_layer

        self.fc_hid = nn.Linear(in_features=self.input_size,
                                out_features=fc_hid_size,
                                bias=True)
        self.fc_out = nn.Linear(in_features=self.fc_hid_size,
                                out_features=2,
                                bias=True)

    def forward(self, x):
        batch_size = x.size(0)
        frame_length = x.size(1)

        out = torch.relu(self.fc_hid(x))
        out = self.fc_out(out)  # Dim: (batch_size * n_windows, 2)
        out = out.view(batch_size, frame_length, 2)
        return out
