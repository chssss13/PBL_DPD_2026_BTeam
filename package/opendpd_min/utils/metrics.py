__author__ = "Yizhuo Wu, Chang Gao"
__license__ = "Apache-2.0 License"
__email__ = "yizhuo.wu@tudelft.nl, chang.gao@tudelft.nl"

from typing import Tuple
import numpy as np
import os

def magnitude_spectrum(input_signal: np.ndarray[np.complex128],
                       sample_rate: int,
                       nfft: int,
                       shift: bool = False) -> Tuple[np.ndarray, np.ndarray]:
    """
    Compute the Fast Fourier Transform (FFT) of the input signal.

    Parameters:
    - input_signal (np.ndarray[np.complex128]): A 2D numpy array where the first dimension
                                               represents batch size and the second dimension
                                               represents the time sequence of complex numbers.
    - sample_rate (int): The rate at which the input signal was sampled.
    - shift (bool, optional): Whether or not to shift the zero-frequency component to
                              the center of the spectrum. Defaults to False.

    Returns:
    - Tuple[np.ndarray, np.ndarray]: A tuple where the first element is the frequency components
                                     and the second element is the FFT of the input signal for each batch.
    """
    # Compute the FFT of the input signal along the last axis (time sequence dimension)
    spectrum = np.fft.fft(input_signal, n=nfft, axis=-1)
    # Shift the zero-frequency component to the center if `shift` is True
    if shift:
        spectrum = np.fft.fftshift(spectrum, axes=-1)
        if(len(input_signal.shape) ==2):
            freq = np.fft.fftshift(np.fft.fftfreq(input_signal.shape[1], d=1 / sample_rate))
        else:
            freq = np.fft.fftshift(np.fft.fftfreq( nfft, d=1 / sample_rate))
    else:
        # Generate the frequencies for the unshifted spectrum
        freq = np.linspace(0, sample_rate, input_signal.shape[1])

    return freq, spectrum

def MSE(prediction, ground_truth):
    i_hat = prediction[..., 0]
    i_true = ground_truth[..., 0]
    q_hat = prediction[..., 1]
    q_true = ground_truth[..., 1]

    MSE = np.mean(np.square(i_true - i_hat) + np.square(q_true - q_hat), axis=-1)
    return MSE

def NMSE(prediction, ground_truth):
    i_hat = prediction[..., 0]
    i_true = ground_truth[..., 0]
    q_hat = prediction[..., 1]
    q_true = ground_truth[..., 1]

    MSE = np.mean(np.square(i_true - i_hat) + np.square(q_true - q_hat), axis=-1)
    energy = np.mean(np.square(i_true) + np.square(q_true), axis=-1)

    NMSE = np.mean(10 * np.log10(MSE / energy))
    return NMSE


def EVM(prediction, ground_truth, sample_rate=int(800e6), bw_main_ch=200e6, n_sub_ch=10, nperseg=2560):
    """
    Calculate EVM based on the given formula.

    Parameters:
    - prediction (array): Prediction/measurements of the PA or DPD-PA outputs.
    - ground_truth (array): Desired output of PA.
    - sample_rate (int, optional): Sampling rate. Default is 800e6.
    - bw_main_ch (float, optional): Bandwidth of main channel. Default is 200e6.
    - n_sub_ch (int, optional): Number of sub-channels. Default is 10.
    - nperseg (int, optional): Length of each segment for the FFT. If not provided, use the entire signal. Default is 2560.

    Returns:
    - float: EVM value in dB.
    """
    #if(len(prediction.shape) ==2):
    #    nperseg = prediction.shape[0]
    # Convert to Complex Array
    prediction_complex = prediction[..., 0] + 1j * prediction[..., 1]
    freq, spectrum_prediction = magnitude_spectrum(prediction_complex, sample_rate=sample_rate, nfft=nperseg,
                                                   shift=True)
    ground_truth_complex = ground_truth[..., 0] + 1j * ground_truth[..., 1]
    freq, spectrum_ground_truth = magnitude_spectrum(ground_truth_complex, sample_rate=sample_rate, nfft=nperseg,
                                                     shift=True)

    import pandas as pd
    data = pd.DataFrame({"freq" : freq})
    data.to_csv("freq.csv")

    # Determine the indices for the main channel
    index_left = np.min(np.where(freq >= -bw_main_ch / 2))
    index_right = np.max(np.where(freq <= bw_main_ch / 2))

    # Determine the index length for each sub-channel
    channel_index_len = int((index_right - index_left) / n_sub_ch)
    #check constellationn of prediction
    #plt_constellation(prediction_complex,ground_truth_complex)
    #IQ = complex_to_IQ(spectrum_ground_truth)
    #from utils.util import print_IQ_data
    #print_IQ_data(IQ,"spectrum")
    #plot_psd(prediction_complex,ground_truth_complex)
    # Initialize error array
    
    # Calculate the error for each sub-channel
    if (len(spectrum_ground_truth.shape) !=1):
        error = np.zeros((prediction.shape[0], n_sub_ch))
        for c in range(n_sub_ch):
            error[:, c] = np.mean(np.abs(
                spectrum_prediction[:, index_left + c * channel_index_len:index_left + (c + 1) * channel_index_len]
                - spectrum_ground_truth[:, index_left + c * channel_index_len:index_left + (c + 1) * channel_index_len]),
                axis=-1)

            # Normalize the error by the magnitude of the ground truth
            error[:, c] = error[:, c] / np.mean(
                np.abs(
                    spectrum_ground_truth[:, index_left + c * channel_index_len:index_left + (c + 1) * channel_index_len]),
                axis=-1)
    else:
        error = np.zeros(n_sub_ch)
        for c in range(n_sub_ch):
            error[c] = np.mean(np.abs(
                spectrum_prediction[index_left + c * channel_index_len:index_left + (c + 1) * channel_index_len]
                - spectrum_ground_truth[index_left + c * channel_index_len:index_left + (c + 1) * channel_index_len]),
                axis=-1)
            # Normalize the error by the magnitude of the ground truth
            error[c] = error[c] / np.mean(
                np.abs(
                    spectrum_ground_truth[index_left + c * channel_index_len:index_left + (c + 1) * channel_index_len]),
                axis=-1)

    # Average error across sub-channels
    EVM_avg_seq = error.mean(axis=-1)

    # Convert error to dB
    EVM_db = 20 * np.log10(np.mean(EVM_avg_seq))

    return EVM_db


def ACLR(prediction, fs=800e6, nperseg=2560, bw_main_ch=200e6, n_sub_ch=10):
    """
    Calculates the left and right Adjacent Channel Leakage Ratio (ACLR).

    Parameters:
    - frequencies: Array of frequency values from the Welch method.
    - psd: Power Spectral Density values corresponding to the frequencies.
    - bw_main_ch: Bandwidth of the main channel baseband signals (default is 200e6).
    - bw_side_ch: Bandwidth of the side channel baseband signals (default is 20e6).

    Returns:
    - aclr_left: ACLR value for the left adjacent channel.
    - aclr_right: ACLR value for the right adjacent channel.
    """
    # Get complex signal
    complex_signal = IQ_to_complex(prediction)

    # Calculate power spectral density
    #nperseg = 7560
    freq, psd = power_spectrum(complex_signal, fs=fs, nperseg=nperseg, axis=-1)

    # Compute the left and right index of the main channel
    index_left = np.min(np.where(freq >= -bw_main_ch / 2))
    index_right = np.max(np.where(freq <= bw_main_ch / 2))
    # Compute the length in index of each subchannel
    sub_ch_index_len = int((index_right - index_left) / n_sub_ch)

    # Compute the power of each subchannel and find the maximum power
    sub_ch_power = np.zeros((n_sub_ch))
    for c in range(n_sub_ch):
        sub_ch_power[c] = np.sum(
            psd[index_left + c * sub_ch_index_len:index_left + (c + 1) * sub_ch_index_len])
    max_sub_ch_power = sub_ch_power.max()

    # Compute ACLR for left and right adjacent channels
    left_side_ch_power = np.sum(psd[index_left - sub_ch_index_len:index_left])
    aclr_left = np.mean(10 * np.log10(left_side_ch_power / max_sub_ch_power))
    right_side_channel_power = np.sum(psd[index_right:index_right + sub_ch_index_len])
    aclr_right = np.mean(10 * np.log10(right_side_channel_power / max_sub_ch_power))

    return aclr_left, aclr_right


def power_spectrum(complex_signal, fs=800e6, nperseg=2560, axis=-1):
    """
    Compute the Power Spectral Density (PSD) of a given complex signal using the Welch method.

    Parameters:
    - complex_signal: Input complex signal for which the PSD is to be computed.
    - fs (float, optional): Sampling frequency of the signal. Default is 800e6 (800 MHz).
    - nperseg (int, optional): Number of datasets points to be used in each block for the Welch method. Default is 2560.

    Returns:
    - frequencies_signal_subset: Frequencies at which the PSD is computed.
    - psd_signal_subset: PSD values.
    """

    import numpy as np
    from scipy.signal import welch
    # Compute the PSD using the Welch method
    freq, ps = welch(complex_signal, fs=fs, nperseg=nperseg,
                      return_onesided=False, scaling='spectrum', axis=-1)
    # To make the frequency axis monotonic, we need to shift the zero frequency component to the center.
    # This step rearranges the computed PSD and frequency values such that the negative frequencies appear first.
    half_nfft = int(nperseg / 2)
    freq = np.concatenate(
        (freq[half_nfft:], freq[:half_nfft]))

    # Rearrange the PSD values corresponding to the rearranged frequency values.
    ps = np.concatenate((ps[..., half_nfft:], ps[..., :half_nfft]), axis=-1)

    # Take the average of all signals
    if len(ps.shape) > 1:
        ps = np.mean(ps, axis=0)

    return freq, ps


def IQ_to_complex(IQ_signal):
    """
    Convert a multi-dimensional array of I-Q pairs into a 2D array of complex signals.

    Args:
    - IQ_in_segment (3D array): The prediction I-Q datasets with shape (#segments, frame_length, 2).

    Returns:
    - 2D array of shape (#segments, frame_length) containing complex signals.
    """

    # Extract I and Q values
    I_values = IQ_signal[..., 0]
    Q_values = IQ_signal[..., 1]

    # Convert to complex signals
    complex_signals = I_values + 1j * Q_values

    return complex_signals

def complex_to_IQ(complex_tensor):
    import torch
    """
    Convert a 1D array of complex signals into a multi-dimensional array of I-Q pairs. 

    Args:

    Returns:
    - 2D array of shape (#segments, frame_length) containing complex signals.
    """
    I = complex_tensor.real.float()
    Q = complex_tensor.imag.float()
    return torch.stack((I, Q), dim=-1)

def moving_average(data, window_size):
        """Compute the moving average of a given dataset."""
        import pandas as pd

        return pd.Series(data).rolling(window=window_size).mean().to_numpy()[window_size - 1:]



def plot_psd(complex_signal_1, complex_signal_2, label_1="wo_DPD", label_2="with_DPD", fs=800e6, nperseg=2560, smoothing_window=10):
    """
    Plots the combined PSD of two I-Q signals.

    Parameters:
    - complex_signal_1: Complex array representing the first I-Q signal (Without DPD).
    - complex_signal_2: Complex array representing the second I-Q signal (With DPD).
    - fs: Sample rate (default is 800e6).
    - nperseg: Number of data points used in each block for the FFT in the Welch method (default is 2560).
    """
    import numpy as np
    from scipy.signal import welch
    import matplotlib.pyplot as plt
    import matplotlib
    matplotlib.use('Agg')

    # Use only the first 2560 data points for both signals
    complex_signal_1_subset = complex_signal_1[:nperseg]
    complex_signal_2_subset = complex_signal_2[:nperseg]

    # Compute the Power Spectral Density (PSD) using the Welch method
    frequencies_signal_1_subset, psd_signal_1_subset = welch(complex_signal_1_subset, fs=fs, nperseg=nperseg,
                                                             return_onesided=False)
    frequencies_signal_2_subset, psd_signal_2_subset = welch(complex_signal_2_subset, fs=fs, nperseg=nperseg,
                                                             return_onesided=False)

    # Make the frequency axis monotonic
    half_nfft = int(nperseg / 2)
    frequencies_signal_1_subset = np.concatenate((frequencies_signal_1_subset[half_nfft:], frequencies_signal_1_subset[:half_nfft]))
    frequencies_signal_2_subset = np.concatenate((frequencies_signal_2_subset[half_nfft:], frequencies_signal_2_subset[:half_nfft]))

    # Make the PSD axis monotonic
    psd_signal_1_subset = np.concatenate(
        (psd_signal_1_subset[half_nfft:], psd_signal_1_subset[:half_nfft]))
    psd_signal_2_subset = np.concatenate(
        (psd_signal_2_subset[half_nfft:], psd_signal_2_subset[:half_nfft]))

    # Normalize the PSD for both signals
    psd_signal_1_normalized_subset = 10 * np.log10(psd_signal_1_subset / np.max(psd_signal_1_subset))
    psd_signal_2_normalized_subset = 10 * np.log10(psd_signal_2_subset / np.max(psd_signal_2_subset))

    # Apply moving average to smooth the data
    psd_signal_1_smoothed = moving_average(psd_signal_1_normalized_subset, smoothing_window)
    psd_signal_2_smoothed = moving_average(psd_signal_2_normalized_subset, smoothing_window)

    # Adjust frequencies for the valid convolution output
    frequencies_signal_1_adjusted = frequencies_signal_1_subset[int(smoothing_window/2):-int(smoothing_window/2)+1]
    frequencies_signal_2_adjusted = frequencies_signal_2_subset[int(smoothing_window/2):-int(smoothing_window/2)+1]

    # Plot the normalized PSD of both signals on the same plot
    plt.figure(figsize=(10, 6))

    # Signal 1
    plt.plot(frequencies_signal_1_adjusted / 1e6, psd_signal_1_smoothed, label=label_1, color='blue')

    # Signal 2
    plt.plot(frequencies_signal_2_adjusted / 1e6, psd_signal_2_smoothed, label=label_2, color='red',
             linestyle='--')

    plt.title('Normalized Power Spectral Density (PSD)')
    plt.xlabel('Frequency (MHz)')
    plt.ylabel('Normalized PSD (dB)')
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(f'psd_{label_2}.jpg')
    return (frequencies_signal_1_subset, psd_signal_1_subset), (frequencies_signal_2_subset, psd_signal_2_subset)

def plt_constellation(complex_signal_1, complex_signal_2, sample_rate=int(800e6), nperseg=2560, n_subc=64, n_ch=10):
    import matplotlib.pyplot as plt
    import matplotlib
    matplotlib.use('TkAgg')
    import numpy as np

    # Size of complex_signal (nperseg)

    spectrum_prediction = np.fft.fft(complex_signal_1, n=nperseg, axis=-1)
    spectrum_prediction = np.fft.fftshift(spectrum_prediction, axes=-1)
    spectrum_ground_truth = np.fft.fft(complex_signal_2, n=nperseg, axis=-1)
    spectrum_ground_truth = np.fft.fftshift(spectrum_ground_truth, axes=-1)

    X_pred = []
    y_pred = []
    X_gt = []
    y_gt = []

    # collect data for each subchannel and normalize
    for i in range(n_ch):
        left_index = int(nperseg / 2) - n_subc * int(n_ch / 2)

        pred_i = spectrum_prediction[left_index + n_subc * i: left_index + n_subc * (i + 1)]
        pred_i /= np.max([np.max(np.abs(np.real(pred_i))), np.max(np.abs(np.imag(pred_i)))])
        X_pred.append(pred_i.real)
        y_pred.append(pred_i.imag)

        gt_i = spectrum_ground_truth[left_index + n_subc * i: left_index + n_subc * (i + 1)]
        gt_i /= np.max([np.max(np.abs(np.real(gt_i))), np.max(np.abs(np.imag(gt_i)))])
        X_gt.append(gt_i.real)
        y_gt.append(gt_i.imag)

    X_pred = np.concatenate(X_pred, axis=0)
    y_pred = np.concatenate(y_pred, axis=0)
    X_gt = np.concatenate(X_gt, axis=0)
    y_gt = np.concatenate(y_gt, axis=0)

    # Plot the constellation diagram of DPD signal and standard modulation signal
    fig, ax = plt.subplots()

    ax.scatter(X_pred, y_pred, c='blue', label="DPD",
               alpha=0.3, edgecolors='none')
    ax.scatter(X_gt, y_gt, c='red', label="Standard",
               alpha=0.3, edgecolors='none')

    ax.legend()
    ax.grid(True)
    plt.savefig("graph.jpg", format="jpg", dpi=300)
    plt.show()
    #################
    # can also plot the constellation diagram of the signal without DPD by changing the complex_signal_2
    # way to use: 
    # metrics.plt_constellation(metrics.IQ_to_complex(prediction[0]), metrics.IQ_to_complex(ground_truth[0]))
    #################
    
    
def plot_psd_list(complex_signals, labels, fs=800e6, nperseg=2560, smoothing_window=10):
    """
    Plots the combined PSD of multiple I-Q signals.

    Parameters:
    - complex_signals: List of complex arrays representing the I-Q signals.
    - labels: List of strings for labeling each signal in the plot.
    - fs: Sample rate (default is 800e6).
    - nperseg: Number of data points used in each block for the FFT in the Welch method (default is 2560).
    - smoothing_window: Window size for moving average smoothing (default is 10).

    Returns:
    - frequencies: Array of frequency values (same for all signals).
    - psd_list: List of PSD arrays for each signal (before normalization).
    """
    import numpy as np
    from scipy.signal import welch, lfilter
    import matplotlib.pyplot as plt
    import matplotlib
    matplotlib.use('Agg')

    # Check that the number of signals matches the number of labels
    if len(complex_signals) != len(labels):
        print(len(complex_signals))
        print(len(labels))
        raise ValueError("The number of complex signals must match the number of labels.")

    # Compute frequencies using the first signal (same for all due to identical fs and nperseg)
    frequencies, _ = welch(complex_signals[0][:nperseg], fs=fs, nperseg=nperseg, return_onesided=False)
    half_nfft = nperseg // 2
    frequencies = np.concatenate((frequencies[half_nfft:], frequencies[:half_nfft]))

    psd_list = []
    psd_smoothed_list = []

    # Process each signal
    for signal in complex_signals:
        _, psd = welch(signal[:nperseg], fs=fs, nperseg=nperseg, return_onesided=False)
        psd = np.concatenate((psd[half_nfft:], psd[:half_nfft]))
        psd_normalized = 10 * np.log10(psd / np.max(psd))
        psd_smoothed = moving_average(psd_normalized, smoothing_window)
        #n=30
        #b=[1.0/n]*n
        #a=1
        #psd_smoothed = lfilter(b,a, psd_smoothed)
        psd_list.append(psd)  # Store PSD before normalization
        psd_smoothed_list.append(psd_smoothed)  # Store smoothed PSD for plotting

    # Adjust frequencies for the valid convolution output
    frequencies_adjusted = frequencies[int(smoothing_window/2):-int(smoothing_window/2)+1]

    # Plot all PSDs
    plt.figure(figsize=(10, 6))
    for psd_smoothed, label in zip(psd_smoothed_list, labels):
        plt.plot(frequencies_adjusted / 1e6, psd_smoothed, label=label)
    plt.title('Normalized Power Spectral Density (PSD)')
    plt.xlabel('Frequency (MHz)')
    plt.ylabel('Normalized PSD (dB)')
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    i=0
    while (True):
      filename = f"psd_{i}.png"
      if os.path.exists(filename):
          i += 1
      else:
          plt.savefig(filename)
          break

    return frequencies, psd_list


def plt_constellation_list(complex_signals, labels, sample_rate=int(800e6), nperseg=2560, n_subc=64, n_ch=10):
    """
    Plots the constellation diagram of multiple I-Q signals.

    Parameters:
    - complex_signals: List of complex arrays representing the I-Q signals.
    - labels: List of strings for labeling each signal in the plot.
    - sample_rate: Sample rate (default is 800e6).
    - nperseg: Number of data points used for FFT (default is 2560).
    - n_subc: Number of subcarriers per channel (default is 64).
    - n_ch: Number of channels (default is 10).
    """
    import numpy as np
    import matplotlib.pyplot as plt
    import matplotlib
    matplotlib.use('Agg')
    # Check that the number of signals matches the number of labels
    if len(complex_signals) != len(labels):
        raise ValueError("The number of complex signals must match the number of labels.")

    fig, ax = plt.subplots()

    # Process each signal
    for signal, label in zip(complex_signals, labels):
        # Compute FFT and shift
        spectrum = np.fft.fft(signal[:nperseg], n=nperseg, axis=-1)
        spectrum = np.fft.fftshift(spectrum, axes=-1)
        X = []
        y = []

        # Extract and normalize subchannels
        for i in range(n_ch):
            left_index = int(nperseg / 2) - n_subc * int(n_ch / 2)
            sub_spectrum = spectrum[left_index + n_subc * i: left_index + n_subc * (i + 1)]
            sub_spectrum[np.isnan(sub_spectrum)] = 0 + 0j
            norm_factor = np.max([np.max(np.abs(np.real(sub_spectrum))), np.max(np.abs(np.imag(sub_spectrum)))])
            if norm_factor != 0:
                sub_spectrum /= norm_factor
            X.append(sub_spectrum.real)
            y.append(sub_spectrum.imag)

        X = np.concatenate(X)
        y = np.concatenate(y)

        # Scatter plot for this signal
        ax.scatter(X, y, label=label, alpha=0.3)#, edgecolors='none')

    ax.legend()
    ax.grid(True)
    i=0
    while (True):
      filename = f"constellation_{i}.png"
      if os.path.exists(filename):
          i += 1
      else:
          plt.savefig(filename)
          break
    
    
    """
    def plt_constellation_list(complex_signals, labels, sample_rate=int(800e6), nperseg=2560, n_subc=64, n_ch=10):
    
    Plots the constellation diagram of multiple I-Q signals in subplots, with 'ground_truth' in all subplots.

    Parameters:
    - complex_signals: List of complex arrays representing the I-Q signals.
    - labels: List of strings for labeling each signal in the plot.
    - sample_rate: Sample rate (default is 800e6). (Currently not used in the function)
    - nperseg: Number of data points used for FFT (default is 2560).
    - n_subc: Number of subcarriers per channel (default is 64).
    - n_ch: Number of channels (default is 10).
    
    import numpy as np
    import matplotlib.pyplot as plt

    # Check that the number of signals matches the number of labels
    if len(complex_signals) != len(labels):
        raise ValueError("The number of complex signals must match the number of labels.")

    # Find the index of 'ground_truth' in the labels list
    try:
        gt_index = labels.index("ground_truth")
    except ValueError:
        raise ValueError("Label 'ground_truth' not found in labels.")

    # Extract the ground truth signal
    gt_signal = complex_signals[gt_index]

    # Create lists of other signals and their labels, excluding 'ground_truth'
    other_indices = [i for i in range(len(labels)) if i != gt_index]
    other_signals = [complex_signals[i] for i in other_indices]
    other_labels = [labels[i] for i in other_indices]

    # Determine the number of subplots based on the number of other signals
    num_subplots = len(other_signals)

    # Create a figure with subplots: one subplot per other signal, arranged vertically
    fig, axes = plt.subplots(num_subplots, 1, figsize=(8, 4 * num_subplots))

    # If there is only one subplot, convert axes to a list to ensure iterability
    if num_subplots == 1:
        axes = [axes]

    # Iterate over each subplot, plotting 'ground_truth' and one other signal
    for ax, signal, label in zip(axes, other_signals, other_labels):
        # Compute the constellation for 'ground_truth'
        spectrum_gt = np.fft.fft(gt_signal[:nperseg], n=nperseg, axis=-1)
        spectrum_gt = np.fft.fftshift(spectrum_gt, axes=-1)
        X_gt = []
        y_gt = []
        for i in range(n_ch):
            # Extract subchannel
            left_index = int(nperseg / 2) - n_subc * int(n_ch / 2)
            sub_spectrum_gt = spectrum_gt[left_index + n_subc * i: left_index + n_subc * (i + 1)]
            # Normalize based on maximum absolute value of real or imaginary parts
            norm_factor_gt = np.max([np.max(np.abs(np.real(sub_spectrum_gt))), np.max(np.abs(np.imag(sub_spectrum_gt)))])
            sub_spectrum_gt /= norm_factor_gt
            X_gt.append(sub_spectrum_gt.real)
            y_gt.append(sub_spectrum_gt.imag)
        # Concatenate all subchannels' real and imaginary parts
        X_gt = np.concatenate(X_gt)
        y_gt = np.concatenate(y_gt)

        # Compute the constellation for the other signal
        spectrum = np.fft.fft(signal[:nperseg], n=nperseg, axis=-1)
        spectrum = np.fft.fftshift(spectrum, axes=-1)
        X = []
        y = []
        for i in range(n_ch):
            # Extract subchannel
            left_index = int(nperseg / 2) - n_subc * int(n_ch / 2)
            sub_spectrum = spectrum[left_index + n_subc * i: left_index + n_subc * (i + 1)]
            # Normalize based on maximum absolute value of real or imaginary parts
            norm_factor = np.max([np.max(np.abs(np.real(sub_spectrum))), np.max(np.abs(np.imag(sub_spectrum)))])
            sub_spectrum /= norm_factor
            X.append(sub_spectrum.real)
            y.append(sub_spectrum.imag)
        # Concatenate all subchannels' real and imaginary parts
        X = np.concatenate(X)
        y = np.concatenate(y)

        # Plot the 'ground_truth' constellation on the current subplot
        ax.scatter(X_gt, y_gt, label="ground_truth", alpha=0.3, edgecolors='none')

        # Plot the other signal's constellation on the same subplot
        ax.scatter(X, y, label=label, alpha=0.3, edgecolors='none')

        # Add a legend to distinguish between 'ground_truth' and the other signal
        ax.legend()

        # Set the title of the subplot to indicate which signals are being compared
        ax.set_title(f"Constellation: {label} vs ground_truth")

        # Add a grid for better readability
        ax.grid(True)

    # Adjust the layout to prevent overlapping of subplots
    plt.tight_layout()

    # Display the figure
    plt.show()
        """


def plt_AM_AM_PM(input_complex_signals : complex, output_complex_signals : complex, labels, sample_rate=int(800e6), nperseg=2560, n_subc=64, n_ch=10):
    """
    Plots the constellation diagram of multiple I-Q signals.

    Parameters:
    - complex_signals: List of complex arrays representing the I-Q signals.
    - labels: List of strings for labeling each signal in the plot.
    - sample_rate: Sample rate (default is 800e6).
    - nperseg: Number of data points used for FFT (default is 2560).
    - n_subc: Number of subcarriers per channel (default is 64).
    - n_ch: Number of channels (default is 10).
    """
    import numpy as np
    import matplotlib.pyplot as plt
    import matplotlib
    matplotlib.use('Agg')
    # Check that the number of signals matches the number of labels
    if len(output_complex_signals) != len(labels):
        raise ValueError("The number of complex signals must match the number of labels.")

    fig, axes = plt.subplots(1,2)
    AM_i = np.abs(input_complex_signals)
    PM_i = np.angle(input_complex_signals)
    # Process each signal
    for o_signal, label in zip(output_complex_signals, labels):
        # Scatter plot for this signal        
        # graph y
        AM_o = np.abs(o_signal)
        PM_o = np.angle(o_signal)
        PM_diff = (np.unwrap(PM_o - PM_i + np.pi) % (2*np.pi) - np.pi)/np.pi * 180
        #AM/AM
        axes[0].scatter(AM_i, AM_o, label=label, alpha=0.3)#, edgecolors='none')
        axes[0].set_title("AM/AM")
        axes[0].set_xlabel("Input Magnitude")
        axes[0].set_ylabel("Output Magnitude")
        #AM/PM
        axes[1].scatter(AM_i, PM_diff, label=label, alpha=0.3)#, edgecolors='none')
        plt.xlim([0.4,1])
        plt.ylim([-20,20])
        axes[1].set_title("AM/PM")
        axes[1].set_xlabel("Input Magnitude")
        axes[1].set_ylabel("Output Phase (degree)")

    axes[0].legend()
    axes[1].legend()
    axes[0].grid(True)
    axes[1].grid(True)
    
    plt.tight_layout()
    plt.savefig(f'NL_{labels[0]}.png')
    plt.show()



def analysis_noise(input_complex_signals : complex, output_complex_signals : complex, labels):
    """
    Plots the constellation diagram of multiple I-Q signals.

    Parameters:
    - complex_signals: List of complex arrays representing the I-Q signals.
    - labels: List of strings for labeling each signal in the plot.
    - sample_rate: Sample rate (default is 800e6).
    - nperseg: Number of data points used for FFT (default is 2560).
    - n_subc: Number of subcarriers per channel (default is 64).
    - n_ch: Number of channels (default is 10).
    """
    import numpy as np
    import matplotlib.pyplot as plt
    import matplotlib
    matplotlib.use('TkAgg')
    # Check that the number of signals matches the number of labels
    print()
    if len(output_complex_signals) != len(labels):
        print(len(output_complex_signals))
        print(len(labels))
        raise ValueError("The number of complex signals must match the number of labels.")
    
    AM_i = np.abs(input_complex_signals)
    max_val = max(AM_i)
    min_val = min(AM_i)
    slice_num = 100
    bin_edges = np.linspace(min_val, max_val, slice_num + 1)
    bin_indices = np.digitize(AM_i, bin_edges)


    # Process each signal
    result = {'name' : labels, 'max_var' : [], 'mean_var' : [] ,'snr_am_am' : []}
    for o_signal in output_complex_signals:
        AM_o = np.abs(o_signal)
        gain = max(AM_o)/max_val
        signal_power = np.mean((AM_i) ** 2)
        sub_var = []
        for i in range(slice_num+1):
            idx = np.where(bin_indices == i + 1)[0]
            if len(idx) > 0:
                sub_var.append(np.var(AM_o[idx]))
        #print(sum(sub_var))
        #print(np.mean(sub_var))
        #print(sub_var)
        mean_var =sum(sub_var)/len(sub_var)
        result['max_var'].append(max(sub_var))
        result['mean_var'].append(mean_var)
            # Method 1: Estimate SNR using AM/AM variance as noise power
        noise_power = np.mean(np.abs(input_complex_signals - o_signal)**2)
        if noise_power> 0:  # Avoid division by zero
            snr_am_am = signal_power / noise_power
            snr_am_am_db = 10 * np.log10(snr_am_am)
        else:
            snr_am_am_db = float('inf')  # If variance is 0, SNR is theoretically infinite
        result['snr_am_am'].append(snr_am_am_db)

    import pandas as pd
    pd_result = pd.DataFrame(result)
    pd_result.to_excel("PA_vars.xlsx")
    print(pd_result)
        
    #plt.plot(pd_result['mean_var'], pd_result['snr_am_am'], linestyle = '-', marker = 'o')
    #plt.show()

    return result


def analysis_nonlinearity(input_complex_signals : complex, output_complex_signals : complex, labels):
    """
    Plots the constellation diagram of multiple I-Q signals.

    Parameters:
    - complex_signals: List of complex arrays representing the I-Q signals.
    - labels: List of strings for labeling each signal in the plot.
    - sample_rate: Sample rate (default is 800e6).
    - nperseg: Number of data points used for FFT (default is 2560).
    - n_subc: Number of subcarriers per channel (default is 64).
    - n_ch: Number of channels (default is 10).
    """
    import numpy as np
    import matplotlib.pyplot as plt
    import matplotlib
    import pandas as pd
    matplotlib.use('TkAgg')
    # Check that the number of signals matches the number of labels
    if len(output_complex_signals) != len(labels):
        raise ValueError("The number of complex signals must match the number of labels.")
    
    AM_i = np.abs(input_complex_signals)
    max_val = max(AM_i)
    min_val = min(AM_i)
    slice_num = 30
    bin_edges = np.linspace(min_val, max_val, slice_num + 1)
    bin_centers = 0.5 * (bin_edges[:-1] + bin_edges[1:])
    bin_indices = np.digitize(AM_i, bin_edges)
    # Process each signal
    result = {'name' : labels, 'NMSE' : []}
    no_noise_signals = []
    for j, o_signal in enumerate(output_complex_signals):
        AM_o = np.abs(o_signal)
        gain = max(AM_o)/max_val
        
        func_points = []
        for i in range(slice_num+1):
            idx = np.where(bin_indices == i + 1)[0]
            if len(idx) > 0:
                func_points.append(np.mean(AM_o[idx]))
            else:
                func_points.append(np.nan)

        func_points = pd.Series(func_points).interpolate().to_numpy()

        slop = []
        for i in range(slice_num):
            slop.append((func_points[i+1]-func_points[i])/(max_val/slice_num))
            
        #print("#######################")
        no_noise = o_signal.copy()
        for i in range(slice_num):
            idx = np.where(bin_indices == i + 1)[0]
            if len(idx) > 0:
                no_noise[idx] = ((slop[i]*(AM_i[idx]-bin_edges[i])+func_points[i])/AM_o[idx])* o_signal[idx] 
        o = []
        o.append(o_signal)
        analysis_noise(no_noise,o, [labels[j]])
        no_noise_signals.append(no_noise)
        ground_truth = gain * bin_edges

        extracted_func = func_points

        #plt.plot(bin_centers, o_signal, linestyle = '--', marker = 'o')
        #plt.plot(bin_centers, ground_truth, linestyle = '-', marker = 's')
        #NMSE
        NMSE = np.mean(((ground_truth - extracted_func)**2)/ground_truth)
        result['NMSE'].append(NMSE)
    #plt.show()
    #plt_AM_AM_PM(input_complex_signals,no_noise_signals, labels)
    #plot_psd(output_complex_signals[-1],no_noise_signals[-1])
    
    pd_result = pd.DataFrame(result)
    pd_result.to_excel("PA_nonlinearity.xlsx")
    #print(pd_result)
        
    

    return result, no_noise_signals

