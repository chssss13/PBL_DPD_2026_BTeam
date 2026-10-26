__author__ = "Yizhuo Wu, Chang Gao"
__license__ = "Apache-2.0 License"
__email__ = "yizhuo.wu@tudelft.nl, chang.gao@tudelft.nl"

import torch
import torch.nn as nn
from backbones.rvtdcnn import RVTDCNN
from utils.metrics import complex_to_IQ, IQ_to_complex

class CoreModel(nn.Module):
    def __init__(self, input_size, hidden_size, num_layers, backbone_type,act_degree = 3, residual_type = 1):
        super(CoreModel, self).__init__()
        self.output_size = 2  # PA outputs: I & Q
        self.input_size = input_size
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        self.backbone_type = backbone_type
        self.batch_first = True  # Force batch first
        self.bidirectional = False
        self.bias = True
        self.act_degree = act_degree
        self.c = False
        self.h = False
        if backbone_type == 'gmp':
            from backbones.gmp import GMP
            self.backbone = GMP(memory_length=self.hidden_size, degree=self.num_layers)
        elif backbone_type == 'gru':
            from backbones.gru import GRU
            self.backbone = GRU(input_size=self.input_size,
                                hidden_size=self.hidden_size,
                                output_size=self.output_size,
                                num_layers=self.num_layers,
                                bidirectional=self.bidirectional,
                                batch_first=self.batch_first,
                                bias=self.bias)
        elif backbone_type[0] == 'c' :
            self.c = True
            if backbone_type.startswith('cgru'):
                model = 'GRU'
            elif backbone_type.startswith('clstm'):
                model = 'LSTM'
            elif backbone_type.startswith('crnn'):
                model = 'RNN'
            elif backbone_type.startswith('cdgru'):
                model = 'GRU'
            else:
                raise ValueError(f"Unsupported backbone type: {backbone_type}")
            if backbone_type.endswith('wfex'):
                fex = True
            else:
                fex = False
            from backbones.cgru import SimpleRNNBlock
            self.backbone = SimpleRNNBlock(input_size=self.input_size,
                                hidden_size=self.hidden_size,
                                output_size=self.output_size,
                                num_layers=self.num_layers,
                                rnn_type=model,
                                fex=fex)
        elif backbone_type[0] == 'r' :
            self.h=True
            if backbone_type.startswith('rgru'):
                model = 'GRU'
            elif backbone_type.startswith('rlstm'):
                model = 'LSTM'
            elif backbone_type.startswith('rrnn'):
                model = 'RNN'
            elif backbone_type.startswith('rdgru'):
                model = 'GRU'
            else:
                if backbone_type.startswith('rnn'):
                    model = 'RNN'
                    self.backbone = SimpleRNNBlock(input_size=self.input_size,
                                hidden_size=self.hidden_size,
                                output_size=self.output_size,
                                num_layers=self.num_layers,
                                rnn_type=model,
                                fex=fex)
                raise ValueError(f"Unsupported backbone type: {backbone_type}")
            if backbone_type.endswith('wfex'):
                fex = True
            else:
                fex = False
            if residual_type == 0:
                RM = 'no'
            elif residual_type == 1:
                RM = 'proposed'
            elif residual_type ==2:
                RM = 'conventional'
            elif residual_type == 3:
                RM = 'proposed_resU'
            else:
                ValueError(f"Unsupported residual type: {residual_type}")
            from backbones.cgru import ResidualRNNBlock
            self.backbone = ResidualRNNBlock(input_size=self.input_size,
                                hidden_size=self.hidden_size,
                                output_size=self.output_size,
                                num_layers=self.num_layers,
                                rnn_type=model,
                                fex=fex,
                                act_type=self.act_degree,
                                residual_mode= RM)
        elif backbone_type == 'lwgrurelu':
            from backbones.lw_resrnnrelu import ResidualRNNBlock
            self.backbone = ResidualRNNBlock(input_size=self.input_size,
                                hidden_size=self.hidden_size,
                                output_size=self.output_size,
                                num_layers=self.num_layers,
                                rnn_type="GRU",
                                fex=True,
                                )
        elif backbone_type == 'grufex':
            from backbones.grufex import GRU
            self.backbone = GRU(input_size=self.input_size,
                                hidden_size=self.hidden_size,
                                output_size=self.output_size,
                                num_layers=self.num_layers,
                                bidirectional=self.bidirectional,
                                batch_first=self.batch_first,
                                bias=self.bias)
        elif backbone_type == 'dgru_prelu':
            from backbones.dgru_prelu import DGRU
            self.backbone = DGRU(hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'dgru':
            from backbones.dgru import DGRU
            self.backbone = DGRU(hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'dgruwofex':
            from backbones.dgruwofex import DGRU
            self.backbone = DGRU(hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'rru':
            from backbones.rru import RRU
            self.backbone = RRU(hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'pnrru':
            from backbones.pnrru import PNRRU
            self.backbone = PNRRU(hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'spnrru':
            from backbones.pnrru import SPNRRU
            self.backbone = SPNRRU(hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'cpnrru':
            from backbones.cpnrru import CPNRRU
            self.backbone = CPNRRU(hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'qgru':
            from backbones.qgru import QGRU
            self.backbone = QGRU(hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'qgru_amp1':
            from backbones.qgru_amp1 import QGRU
            self.backbone = QGRU(hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'lstm':
            from backbones.lstm import LSTM
            self.backbone = LSTM(input_size=self.input_size,
                                 hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'lstmfex':
            from backbones.lstmfex import LSTM
            self.backbone = LSTM(input_size=self.input_size,
                                 hidden_size=self.hidden_size,
                                 output_size=self.output_size,
                                 num_layers=self.num_layers,
                                 bidirectional=self.bidirectional,
                                 batch_first=self.batch_first,
                                 bias=self.bias)
        elif backbone_type == 'vdlstm':
            from backbones.vdlstm import VDLSTM
            self.backbone = VDLSTM(input_size=self.input_size,
                                   hidden_size=self.hidden_size,
                                   output_size=self.output_size,
                                   num_layers=self.num_layers,
                                   bidirectional=self.bidirectional,
                                   batch_first=self.batch_first,
                                   bias=self.bias)
        
        elif backbone_type == 'rvtdcnn':
            self.backbone = RVTDCNN(fc_hid_size=self.hidden_size, kernel_size = self.num_layers)
        else:
            raise ValueError(f"The backbone type '{self.backbone_type}' is not supported. Please add your own "
                             f"backbone under ./backbones and update models.py accordingly.")

        # Initialize backbone parameters
        try:
            self.backbone.reset_parameters()
            #print("Backbone Initialized...")
        except AttributeError:
            pass

    def forward(self, x, h_0=None):
        device = x.device
        batch_size = x.size(0)  # NOTE: dim of x must be (batch, time, feat)/(N, T, F)
        
        if h_0 is None:  # Create initial hidden states if necessary
            h_0 = torch.zeros(self.num_layers, batch_size, self.hidden_size).to(device)

        # Forward Propagate through the RNN
        out = self.backbone(x, h_0)

        return out


class CascadedModel(nn.Module):
    def __init__(self, dpd_model  : CoreModel , pa_model  : CoreModel):
        super(CascadedModel, self).__init__()
        self.dpd_model = dpd_model
        self.pa_model = pa_model

    def freeze_pa_model(self):
        for param in self.pa_model.parameters():
            param.requires_grad = False

    def freeze_dpd_model(self):
        for param in self.dpd_model.parameters():
            param.requires_grad = False
    def freeze_model(self):
        self.freeze_dpd_model()
        self.freeze_pa_model()
    
    def forward(self, x):
        x = self.dpd_model(x)
        if isinstance(x, tuple):
            x = x[0]  # output 텐서만 추출
        else:
            x = x
        x = self.pa_model(x)
        return x
    
from backbones.nonlinearity_lut import LUTOperator
class HybridModel(nn.Module):
    def __init__(self, rnn_model : CoreModel, lut_model):
        super(HybridModel, self).__init__()
        self.rnn_model = rnn_model
        self.lut_model = lut_model

    def freeze_rnn_model(self):
        for param in self.rnn_model.parameters():
            param.requires_grad = False
    
    def forward(self, x):
        x1 = self.lut_model(x)
        x2 = self.rnn_model(x)
        x = x1+x2
        if isinstance(x, tuple):
            x = x[0]  # output 텐서만 추출
        else:
            x = x

        return x
