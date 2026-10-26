__author__ = "Yizhuo Wu, Chang Gao"
__license__ = "Apache-2.0 License"
__email__ = "yizhuo.wu@tudelft.nl, chang.gao@tudelft.nl"

import os
import pandas as pd
import numpy as np
import torch
from torch.utils.data import Dataset


def load_dataset(dataset_name):
    path_dataset = os.path.join('datasets', dataset_name)
    X_train = pd.read_csv(os.path.join(path_dataset, 'train_input.csv')).to_numpy()
    y_train = pd.read_csv(os.path.join(path_dataset, 'train_output.csv')).to_numpy()
    X_val = pd.read_csv(os.path.join(path_dataset, 'val_input.csv')).to_numpy()
    y_val = pd.read_csv(os.path.join(path_dataset, 'val_output.csv')).to_numpy()
    X_test = pd.read_csv(os.path.join(path_dataset, 'test_input.csv')).to_numpy()
    y_test = pd.read_csv(os.path.join(path_dataset, 'test_output.csv')).to_numpy()
    return X_train, y_train, X_val, y_val, X_test, y_test


def prepare_segments(args):
    """
    Split the IQ_data into segments of size nperseg. Zero padding is applied
    if the last section is not of length nperseg.
    """
    nperseg = args.nperseg
    path_dataset = os.path.join('datasets', args.dataset_name)
    train_input = pd.read_csv(os.path.join(path_dataset, 'train_input.csv'))
    train_output = pd.read_csv(os.path.join(path_dataset, 'train_output.csv'))
    val_input = pd.read_csv(os.path.join(path_dataset, 'val_input.csv'))
    val_output = pd.read_csv(os.path.join(path_dataset, 'val_output.csv'))
    test_input = pd.read_csv(os.path.join(path_dataset, 'test_input.csv'))
    test_output = pd.read_csv(os.path.join(path_dataset, 'test_output.csv'))

    def split_segments(IQ_data):
        num_samples = IQ_data.shape[0]
        segments = []
        for i in range(0, num_samples, nperseg):
            segment = IQ_data[i:i + nperseg]
            if segment.shape[0] < nperseg:
                padding_shape = (nperseg - segment.shape[0], 2)
                segment = torch.vstack((segment, torch.zeros(padding_shape)))
            segments.append(segment)
        return np.array(segments)

    train_input_segments = split_segments(train_input)
    train_output_segments = split_segments(train_output)
    val_input_segments = split_segments(val_input)
    val_output_segments = split_segments(val_output)
    test_input_segments = split_segments(test_input)
    test_output_segments = split_segments(test_output)

    return train_input_segments, train_output_segments, val_input_segments, val_output_segments, test_input_segments, test_output_segments


def get_training_frames(segments, seq_len, stride=1):
    """
    For each segment, apply the framing operation.

    Args:
    - segments (3D array): The segments produced by get_ofdm_segments.
    - seq_len (int): The length of each frame.
    - stride_length (int, optional): The step between frames. Default is 1.

    Returns:
    - 3D array where the first dimension is the total number of frames,
      the second dimension is seq_len, and the third dimension is 2 (I and Q).
    """

    all_frames = []
    for segment in segments:
        num_frames = (segment.shape[0] - seq_len) // stride + 1
        for i in range(num_frames):
            frame = segment[i * stride: i * stride + seq_len]
            all_frames.append(frame)

    return np.array(all_frames)


class IQSegmentDataset(Dataset):
    def __init__(self, features, targets, nperseg=16384):
        self.nperseg = nperseg

        features = self.split_segments(features)
        targets = self.split_segments(targets)
        self.features = torch.Tensor(features)
        self.targets = torch.Tensor(targets)

    def split_segments(self, sequence):
        num_samples = len(sequence)
        segments = []
        for i in range(0, num_samples, self.nperseg):
            segment = sequence[i:i + self.nperseg]
            if len(segment) < self.nperseg:
                padding_shape = (self.nperseg - segment.shape[0], 2)
                segment = torch.vstack((segment, torch.zeros(padding_shape)))
            segments.append(segment)
        return np.array(segments)

    def __len__(self):
        return len(self.features)

    def __getitem__(self, idx):
        features = self.features[idx, ...]
        targets = self.targets[idx, ...]
        return features, targets


class IQFrameDataset(Dataset):
    def __init__(self, features, targets, frame_length, stride=1):
        # Convert segments into frames
        self.features = torch.Tensor(self.get_frames(features, frame_length, stride))
        self.targets = torch.Tensor(self.get_frames(targets, frame_length, stride))

    @staticmethod
    def get_frames(sequence, frame_length, stride_length):
            frames = []
            sequence_length = len(sequence)
            num_frames = (sequence_length - frame_length) // stride_length + 1
            for i in range(num_frames):
                frame = sequence[i * stride_length: i * stride_length + frame_length]
                frames.append(frame)
            return np.stack(frames)
    def __len__(self):
        return len(self.features)

    def __getitem__(self, idx):
        return self.features[idx], self.targets[idx]


def data_prepare(X, y, frame_length, degree):
    Input = []
    Output = []
    X = torch.Tensor(X)
    y = torch.Tensor(y)
    for k in range(X.shape[0]):
        Complex_In = torch.complex(X[k, :, 0], X[k, :, 1])
        Complex_Out = torch.complex(y[k, :, 0], y[k, :, 1])
        ulength = len(Complex_In) - frame_length
        Input_matrix = torch.complex(torch.zeros(ulength, frame_length),
                                     torch.zeros(ulength, frame_length))
        degree_matrix = torch.complex(torch.zeros(ulength - frame_length, frame_length * frame_length * degree),
                                      torch.zeros(ulength - frame_length, frame_length * frame_length * degree))
        for i in range(ulength):
            Input_matrix[i, :] = Complex_In[i:i + frame_length]
        for j in range(1, degree):
            for h in range(frame_length):
                degree_matrix[:,
                (j - 1) * frame_length * frame_length + h * frame_length:(j - 1) * frame_length * frame_length + (
                        h + 1) * frame_length] = Input_matrix[:ulength - frame_length] * torch.pow(
                    abs(Input_matrix[h:h + ulength - frame_length, :]), j)
        Input_matrix = torch.cat((Input_matrix[:ulength - frame_length], degree_matrix), dim=1)
        b_output = np.array(Complex_Out[:len(Complex_In) - 2 * frame_length])
        b_input = np.array(Input_matrix)
        Input.append(b_input)
        Output.append(b_output)

    return Input, Output


class IQFrameDataset_gmp(Dataset):
    def __init__(self, segment_dataset, frame_length, degree, stride_length=1):
        """
        Initialize the frame dataset using a subset of IQSegmentDataset.

        Args:
        - segment_dataset (IQSegmentDataset): The pre-split segment dataset.
        - seq_len (int): The length of each frame.
        - stride_length (int, optional): The step between frames. Default is 1.
        """

        # Extract segments from the segment_dataset
        IQ_in_segments = [item[0] for item in segment_dataset]
        IQ_out_segments = [item[1] for item in segment_dataset]

        # Convert the list of tensors to numpy arrays
        IQ_in_segments = torch.stack(IQ_in_segments).numpy()
        IQ_out_segments = torch.stack(IQ_out_segments).numpy()

        self.IQ_in_frames, self.IQ_out_frames = data_prepare(IQ_in_segments, IQ_out_segments, frame_length, degree)

    def __len__(self):
        return len(self.IQ_in_frames)

    def __getitem__(self, idx):
        return self.IQ_in_frames[idx], self.IQ_out_frames[idx]

def load_dpd_out():
    folder_path = './dpd_out/'
    file_list = os.listdir(folder_path)
    name = {}
    #name_space = ['DGRU_918', 'DRRU_500', 'RRU_764']
    for file in file_list:
        name_data = file.replace(".csv","")
        name_data = name_data.split("_")
        if len(name_data) >= 11 and int(name_data[10])>700:
            NN_name = name_data[4]+"_"+name_data[10]
            if len(name_data)> 11 and (name_data[-1].find("Hz") == -1):
                NN_name = NN_name+"_NL_"+name_data[-1]
            if (NN_name.find("SPNRRU_") != -1) and (NN_name.find("_NL_") != -1):
                #if int(name_data[10]) > 100:
                #if name_data[4]+"_"+name_data[10] in name_space:
                if int(name_data[-5]) != 928:
                    data = pd.read_csv(os.path.join(folder_path, file))
                    data = data.loc[:, data.columns[-2:]]
                    data = data.to_numpy()
                    name[NN_name] = data

    return name

def load_pa_out():
    folder_path = './pa_out/'
    file_list = os.listdir(folder_path)
    name = {}
    #name_space = ['DGRU_918', 'DRRU_500', 'RRU_764']
    for file in file_list:
        name_data = file.replace(".csv","")
        name_data = name_data.split("_")
        if len(name_data) >= 11 and "result" not in name_data:
            NN_name = name_data[4]+"_"+name_data[10]
            if len(name_data)> 11:
                NN_name = NN_name+"_NL_"+name_data[-2]
            if (NN_name.find("PNRRU_") != -1):
                if (NN_name.find("_C_") != -1):
                #if int(name_data[10]) > 100:
                #if name_data[4]+"_"+name_data[10] in name_space:
                    data = pd.read_csv(os.path.join(folder_path, file))
                    data = data.loc[:, data.columns[-2:]]
                    data = data.to_numpy()
                    name[NN_name] = data
                    print(NN_name)

    return name


def load_log(precision = '', model = 'SPNRRU', dataset= "DPA_200MHz"):
    folder_path = f'./log/{dataset}/train_dpd/'
    dir_list = os.listdir(folder_path)
    pre_dir_name = ''
    if precision != "":
        pre_dir_name = f'/{precision}'
    else:
        precision = 'fp32'
    #file_path = []
    mono_name = {}
    hy_name = {}

    activation = ''       
    file_path = f"{folder_path}{pre_dir_name}/best"
    if os.path.exists(file_path):
        file_list = os.listdir(file_path)
        for file in file_list:
            name_data = file.replace(".csv","")
            HY = False
            if name_data.count("HY"):
                name_data = name_data.replace("_HY_1","")
                HY = True
            
            name_data = name_data.split("_")
            if name_data[4] == 'DGRU' and name_data[5] == 'PRELU':
                name_data[4] = 'DGRU_PRELU'
                del name_data[5]

                
            NN_name = file
            seed = name_data[2]
            if name_data[-4] == 'D':
                if name_data[-3] == '-9':
                    activation ='swish'
                elif name_data[-3] == '-8':
                    activation = 'trainable swish'
                elif name_data[-3] == '-7':
                    activation = 'prelu'
                elif name_data[-3] == '-6':
                    activation ='relu'
                elif name_data[-3] == '-5':
                    activation = 'no'
                elif name_data[-3] == '-4':
                    activation = 'squared relu'
                elif name_data[-3] == '-3':
                    activation = 'rational'
                elif name_data[-3] == '-2':
                    activation ='tanh'
                elif name_data[-3] == '-1':
                    activation = 'sigmoid'
                elif name_data[-3] == '0':
                    activation = 'no'
                else:
                    activation = 'poly_' + name_data[-1]
            else:
                activation = 'relu'
            residual = 'no residual'
            if name_data[-2]=='R':
                if name_data[-1]=='0':
                    residual = 'no residual'
                elif name_data[-1]=='1':
                    residual = 'proposed'
                elif name_data[-1]=='2':
                    residual = 'conventional'
                elif name_data[-1] =='3':
                    residual = 'proposed resU'

            
            if name_data[4] == model:
                data = pd.read_csv(os.path.join(file_path, file))
                data = data.loc[:, data.columns[-5:]]
                #data['name'] = name_data[4]
                data['parameter'] = int(name_data[10])
                data['hidden_size'] = int(name_data[6])
                data['activation'] = activation
                data['residual'] = residual
                data['seed'] = seed
                if data['TEST_EVM'].isnull().values.sum() ==0:
                    mono_name[NN_name] = data
                
            if HY:
                if name_data[4] == model:
                    data = pd.read_csv(os.path.join(file_path, file))
                    data = data.loc[:, data.columns[-5:]]
                    #data['name'] = name_data[4]
                    data['parameter'] = int(name_data[10])
                    data['hidden_size'] = int(name_data[6])
                    data['activation'] = activation
                    data['residual'] = residual
                    data['seed'] = seed
                    hy_name[NN_name] = data
    
    return_dict = {}
    results = []
    keys = []
    for name, log in mono_name.items():
            results.append(log)
            keys.append(name)
    if len(results)>0:
        if len(mono_name)>0:
            pd_mono_result = pd.concat(results, keys=keys)
            pd_mono_result = pd_mono_result.set_index(keys = 'parameter').sort_index()
            return_dict[f"{model}_MONO_{precision}"] = pd_mono_result

    hy_results = []
    hy_keys = []
    for name, log in hy_name.items():
            hy_results.append(log)
            hy_keys.append(name)
    if len(hy_results)>0:
        if len(hy_name)>0:
            pd_hy_result = pd.concat(hy_results, keys=keys)
            pd_hy_result = pd_hy_result.set_index(keys = 'parameter').sort_index()
            return_dict[f"{model}_HY_{precision}"] = pd_hy_result
    # data group by model, hidden_size, residual, activation
    # mean, median and var by seed
    # post_analysis_to_csv 
            
    def summay_pd(pd_result : pd.DataFrame,file_name, group_sample = None, random_state = 52):
           # ✅ Grouping and Aggregation
        metrics = ['TEST_NMSE', 'TEST_ACLR_L','TEST_ACLR_R','TEST_ACLR_AVG', 'TEST_EVM']

        # groupby 객체
        
        pd_result = pd_result.reset_index(drop=False)
        print(pd_result)
        if group_sample is not None:
            grouped = pd_result.groupby(['parameter', 'hidden_size', 'residual', 'activation'])
            pd_result = grouped.apply(
                lambda g: g.sample(n=min(group_sample, len(g)), random_state=random_state)
            ).reset_index(drop=True)
        print(pd_result)
        grouped = pd_result.groupby(['parameter', 'hidden_size', 'residual', 'activation'])[metrics]
        
        # size 계산
        size = grouped.size().reset_index(name='size')

        # 통계 summary 계산
        summary = grouped.agg(['mean', 'median', 'std']).reset_index()

        # size와 summary 병합
        # summary.columns은 멀티인덱스 → 이를 평탄화
        summary.columns = ['_'.join(col).strip('_') if isinstance(col, tuple) else col for col in summary.columns]

        # 이제 merge 가능
        summary = pd.merge(summary, size, on=['parameter', 'hidden_size', 'residual', 'activation'])

        # model-activation-parameter별 평균
        splited_df = summary.groupby(['activation', 'residual','hidden_size'])
        summary = []
        for name, df in splited_df:
            #sort by parameter
            df.sort_values(by =['parameter'], axis=0)
            
            layer_num = df.shape[0]
            layers = [1,3,5]
            try : df.insert(len(df.columns),'layer',layers)
            except :
                layers = [i+1 for i in range(layer_num)]
                df.insert(len(df.columns),'layer',layers)
            summary.append(df)
        summary = pd.concat(summary,ignore_index=True)
        # ✅ 저장 (옵션)
        summary.to_csv(f'summary/{file_name}_summary_{dataset}.csv', index=False)
    for key, value in return_dict.items():
        print(key)
        summay_pd(value,key,None)
    print("summary done")
    return return_dict
