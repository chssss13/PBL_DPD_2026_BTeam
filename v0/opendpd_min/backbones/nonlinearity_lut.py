import numpy as np
import torch
import matplotlib.pyplot as plt
import matplotlib
import pandas as pd
from modules.paths import create_folder
import os
#matplotlib.use('TkAgg')
from utils.metrics import IQ_to_complex, complex_to_IQ

def extract_AM_nonlinearity(input_complex_signals : complex, o_signal : complex, slice_num = 30):
    """
    Extracts AM nonlinearity by calculating amplitude mapping and slope between input and output signals.
    
    Parameters:
    - input_complex_signals: Complex array representing the input I-Q signal.
    - o_signal: Complex array representing the output I-Q signal.
    - slice_num: Number of slices for amplitude binning (default is 30).
    
    Returns:
    - LUT: List containing [slopes, bias, edges] for AM nonlinearity.
    """

    AM_i = np.abs(input_complex_signals)
    max_AM_i = max(AM_i)
    min_AM_i = min(AM_i)

    sliced_AM_i = np.linspace(min_AM_i, max_AM_i+1e-6, slice_num+1)
    bin_indices = np.digitize(AM_i, sliced_AM_i)

    AM_o = np.abs(o_signal)
    min_AM_o = min(AM_o)
    edges = list(0.5 * (sliced_AM_i[:-1] + sliced_AM_i[1:]))
    edges.insert(0,min_AM_i)
    edges.append(max_AM_i)


    # Process each signal
    gains = []
    for i in range(slice_num+1):
        idx = np.where(bin_indices == i + 1)[0]
        if len(idx) > 0:
            gains.append(np.mean(AM_o[idx]/AM_i[idx]))
        else:
            gains.append(np.nan)

    gains = list(pd.Series(gains).interpolate().to_numpy())
    gains.append(gains[-1])
    LUT = [gains, edges]
    return LUT

def extract_PM_nonlinearity(input_complex_signals: complex, o_signal: complex, slice_num=30):
    """
    Extracts AM/PM nonlinearity by calculating phase difference mapping between input and output signals.
    
    Parameters:
    - input_complex_signals: Complex array representing the input I-Q signal.
    - o_signal: Complex array representing the output I-Q signal.
    - slice_num: Number of slices for amplitude binning (default is 30).
    
    Returns:
    - LUT: List containing [slopes, bias, edges] for AM/PM nonlinearity.
    """
    # Calculate input amplitude and phase
    AM_i = np.abs(input_complex_signals)
    PM_i = np.angle(input_complex_signals)
    max_AM_i = max(AM_i)
    min_AM_i = min(AM_i)

    # Calculate output phase and phase difference
    PM_o = np.angle(o_signal)
    PM_diff = (np.unwrap(PM_o - PM_i + np.pi) % (2 * np.pi)) - np.pi

    # Create amplitude bins based on input amplitude
    sliced_AM_i = np.linspace(min_AM_i, max_AM_i + 1e-6, slice_num + 1)
    bin_indices = np.digitize(AM_i, sliced_AM_i)

    # Calculate bin edges (midpoints)
    edges = list(0.5 * (sliced_AM_i[:-1] + sliced_AM_i[1:]))
    edges.insert(0, min_AM_i)
    edges.append(max_AM_i)

    # Process sample points (average phase difference in each bin)
    gains = []
    for i in range(slice_num+1):
        idx = np.where(bin_indices == i + 1)[0]
        if len(idx) > 0:
            gains.append(np.mean(PM_diff[idx]/AM_i[idx]))
        else:
            gains.append(np.nan)
    gains.append(gains[-1])
    # Interpolate missing values
    gains = list(pd.Series(gains).interpolate().to_numpy())
    
    # Construct LUT
    LUT = [gains, edges]
    return LUT

def make_lut( dataset_name, AM_slice_num = 40, PM_slice_num =40):
    from modules.data_collector import load_dataset
    input_signal, output_signal, _, _, _, _  = load_dataset(dataset_name)
    in_compl = IQ_to_complex(input_signal)
    out_compl = IQ_to_complex(output_signal)

    AM_LUT = extract_AM_nonlinearity(in_compl,out_compl,AM_slice_num)
    PM_LUT = extract_PM_nonlinearity(in_compl,out_compl,PM_slice_num)

    AM_save = pd.DataFrame({'AM_GAINS' : AM_LUT[0],'AM_EDGES' : AM_LUT[1]})
    PM_save = pd.DataFrame({'PM_GAINS' : PM_LUT[0],'PM_EDGES' : PM_LUT[1]})

    create_folder(["lut"])

    AM_path_file= os.path.join('lut', dataset_name + "_" + "AM" + '.csv')
    PM_path_file= os.path.join('lut', dataset_name + "_" + "PM" + '.csv')
    AM_save.to_csv(AM_path_file, index=False)
    PM_save.to_csv(PM_path_file, index=False)
    print("LUT outputs saved to the ./lut folder.")

def make_inverse_lut( dataset_name,target_gain= 1):

    AM_gains, AM_edges, PM_gains, PM_edges = load_lut(dataset_name,inverse = False)

    def make_inv_gains(in_gains, target_gain):
        inv_gains = np.zeros_like(in_gains)
        for i, gain in enumerate(in_gains):
            if gain == 0:
                inv_gains[i] = np.nan  # 일단 NaN으로
            else:
                inv_gains[i] = target_gain / gain
        # NaN인 부분 선형 보간
        inv_gains = pd.Series(inv_gains).interpolate(method='linear').to_numpy()
        
        for i in range(3):
            diffs = np.diff(inv_gains)
            threshold = 1.6/2**(i)  # 기울기 jump 허용치

            jump_indices = np.where(diffs > threshold)[0]
            # jump 이후 값을 jump 이전 값으로 고정
            for idx in jump_indices:
                inv_gains[idx+1] = inv_gains[idx] + threshold/2

        from scipy.signal import medfilt, savgol_filter
        inv_gains_smooth = medfilt(inv_gains, kernel_size=3)

        inv_gains_smooth = savgol_filter(inv_gains_smooth, window_length=5, polyorder=3)
        
        return inv_gains_smooth

    def make_AM_inv(in_gains, in_edges,target_gain):
        from scipy.interpolate import interp1d
        import numpy as np
        from scipy.interpolate import PchipInterpolator
        from scipy.interpolate import UnivariateSpline


        measured_outputs = in_gains * in_edges

        sorted_indices = np.argsort(measured_outputs)
        measured_outputs_sorted = measured_outputs[sorted_indices]
        in_edges_sorted = in_edges[sorted_indices]

        measured_outputs_unique, unique_indices = np.unique(measured_outputs_sorted, return_index=True)
        in_edges_unique = in_edges_sorted[unique_indices]
        f_inv = interp1d(measured_outputs_unique, in_edges_unique, kind='linear', fill_value = "extrapolate")
        #f_inv = PchipInterpolator(measured_outputs_unique, in_edges_unique, extrapolate=True)
        #spline = UnivariateSpline(measured_outputs_unique, in_edges_unique, s=0.001)
        #inv_gains = spline(target_outputs) / in_edges

        target_outputs = target_gain * in_edges
        #target_outputs_clipped = np.clip(target_outputs, measured_outputs_unique[0], measured_outputs_unique[-1])

        inv_gains = f_inv(target_outputs) / in_edges

        for i in range(len(inv_gains)):
            if inv_gains[i] > 1:
                inv_gains[i] = np.nan

        inv_gains[-1]= target_gain/in_gains[-1]
        inv_gains = pd.Series(inv_gains).interpolate(method='linear').to_numpy()

        #mask = ~np.isnan(inv_gains)
        #spline = UnivariateSpline(in_edges[mask], inv_gains[mask], s=2)
        #inv_gains = spline(in_edges)
        #from scipy.signal import medfilt, savgol_filter
        #inv_gains_smooth = medfilt(inv_gains, kernel_size=3)

        #inv_gains_smooth = savgol_filter(inv_gains_smooth, window_length=5, polyorder=3)
        return inv_gains, in_edges

    def make_PM_inv(in_gains, AM_inv_gains, in_edges):
        expected_inputs = AM_inv_gains * in_edges

        sorted_indices = np.argsort(expected_inputs)
        ex_in_idx = np.digitize(expected_inputs, in_edges)
        
        inv_gains = np.zeros_like(in_gains)
        for i, idx in enumerate(ex_in_idx):
            if idx == len(in_edges):
                idx = len(in_edges)-1
            inv_gains[i] = -in_gains[idx]
        from scipy.signal import medfilt, savgol_filter
        inv_gains = medfilt(inv_gains, kernel_size=3)

        return  inv_gains, in_edges

    AM_inv_gains, AM_inv_edges = make_AM_inv(AM_gains, AM_edges,target_gain)
    PM_inv_gains, PM_inv_edges = make_PM_inv(PM_gains, AM_inv_gains, PM_edges)

    AM_save = pd.DataFrame({'AM_GAINS' : AM_inv_gains,'AM_EDGES' : AM_inv_edges})
    PM_save = pd.DataFrame({'PM_GAINS' : PM_inv_gains,'PM_EDGES' : PM_inv_edges})

    create_folder(["inv_lut"])

    AM_path_file= os.path.join('inv_lut', dataset_name + "_"+ "AM" + '.csv')
    PM_path_file= os.path.join('inv_lut', dataset_name + "_" + "PM" + '.csv')
    AM_save.to_csv(AM_path_file, index=False)
    PM_save.to_csv(PM_path_file, index=False)
    print("LUT outputs saved to the ./lut folder.")

def load_lut(dataset_name, inverse = False):
    folder = ['lut', 'inv_lut']

    if inverse:
        i = 1
    else:
        i=0

    AM_path_file= os.path.join(folder[i], dataset_name + "_"+ "AM" + '.csv')
    PM_path_file= os.path.join(folder[i], dataset_name + "_" + "PM" + '.csv')
    AM_LUT = pd.read_csv(AM_path_file)
    PM_LUT = pd.read_csv(PM_path_file)
    col = AM_LUT.columns
    AM_slopes = AM_LUT[col[0]].to_numpy()
    AM_edges  = AM_LUT[col[1]].to_numpy()
    col = PM_LUT.columns
    PM_slopes = PM_LUT[col[0]].to_numpy()
    PM_edges  = PM_LUT[col[1]].to_numpy()

    return AM_slopes, AM_edges, PM_slopes, PM_edges


def operate_lut(input_signal, dataset_name, ref_in=None, ref_out=None, batch_size=10, inverse=False):
    in_compl = IQ_to_complex(input_signal).to(torch.complex128)

    AM_gains, AM_edges, PM_gains, PM_edges = load_lut(dataset_name, inverse=inverse)
    
    # numpy → torch tensor로 변환
    AM_gains = torch.from_numpy(AM_gains).to(in_compl.device)
    AM_edges  = torch.from_numpy(AM_edges).to(in_compl.device)
    PM_gains = torch.from_numpy(PM_gains).to(in_compl.device)
    PM_edges  = torch.from_numpy(PM_edges).to(in_compl.device)

    AM_input = torch.abs(in_compl)
    PM_input = torch.angle(in_compl)

    # LUT index 찾기: torch.searchsorted 사용 (정렬되어 있다는 전제)
    AM_idx = torch.searchsorted(AM_edges, AM_input)
    PM_idx = torch.searchsorted(PM_edges, AM_input)

    # 경계값 처리
    AM_idx = torch.clamp(AM_idx, max=len(AM_gains)-1)
    PM_idx = torch.clamp(PM_idx, max=len(PM_gains)-1)

    # LUT 적용
    AM_output = AM_gains[AM_idx] * AM_input
    PM_output = PM_input + (PM_gains[PM_idx] * AM_input)

    NL_output = AM_output * torch.exp(1j * PM_output)
    output_complex = NL_output
    #print(np.isnan(AM_gains).sum(), np.isnan(PM_gains).sum())
    if ref_in is not None and ref_out is not None:
        import utils.metrics as mt
        ref_compl = mt.IQ_to_complex(ref_in)
        measrued = mt.IQ_to_complex(ref_out)
        mt.plt_AM_AM_PM(ref_compl,[measrued, output_complex.cpu().numpy()], ['measured', 'modeled'])
        mt.plot_psd_list([measrued, output_complex.cpu().numpy()], ['measured', 'modeled'])
        #mt.plt_constellation_list([measrued, output_complex.cpu().numpy()], ["measured",'modeled'])


    return complex_to_IQ(output_complex)

class LUTOperator:
    def __init__(self, dataset_name, device, inverse=False):
        self.device = device
        AM_gains, AM_edge, PM_gains, PM_edge = load_lut(dataset_name, inverse)

        # numpy → tensor 변환 후 device로
        self.AM_gains = torch.from_numpy(AM_gains).to(self.device).to(torch.float32)
        self.AM_edges  = torch.from_numpy(AM_edge).to(self.device).to(torch.float32)
        self.PM_gains = torch.from_numpy(PM_gains).to(self.device).to(torch.float32)
        self.PM_edges  = torch.from_numpy(PM_edge).to(self.device).to(torch.float32)

    def __call__(self, input_signal):
        in_compl = IQ_to_complex(input_signal).to(torch.complex64)

        AM_input = torch.abs(in_compl)
        PM_input = torch.angle(in_compl)

        AM_idx = torch.searchsorted(self.AM_edges, AM_input)
        PM_idx = torch.searchsorted(self.PM_edges, AM_input)

        AM_idx = torch.clamp(AM_idx, max=len(self.AM_gains)-1)
        PM_idx = torch.clamp(PM_idx, max=len(self.AM_gains)-1)

        AM_output = self.AM_gains[AM_idx] * AM_input
        PM_output = PM_input + self.PM_gains[PM_idx] * (AM_input)

        NL_output = AM_output * torch.exp(1j * PM_output)
        output_complex = NL_output

        return complex_to_IQ(output_complex)
