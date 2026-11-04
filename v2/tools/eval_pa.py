"""DPD 출력(T x 2)을 PA 대리모델에 통과시켜 NMSE / EVM / ACPR을 계산합니다.

opendpd_min 폴더에서 실행합니다 (torch 필요). DPD와 같은 seed(4574)의 PA 모델을 씁니다.

    cd opendpd_min
    python ../tools/eval_pa.py --pa save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt \
        ../golden/vectors/torch_out.txt ../results/hls_out.txt

인자로 준 파일마다 한 줄씩 결과를 출력합니다. 첫 파일과의 차이(Δ)도 함께 보여 줍니다.
지표는 OpenDPD 학습 로그와 같은 방식(spec.json의 nperseg=2560 구간 단위)으로 계산합니다.
7,680 샘플을 한 번에 계산하면 이상적인 출력도 ACPR이 약 −34 dB로 나오므로 그렇게 하지 않습니다.
"""
import argparse
import json
import os
import sys
import types

os.environ.setdefault("CUDA_VISIBLE_DEVICES", "")

import numpy as np
import torch

sys.path.insert(0, os.getcwd())
# OpenDPD의 utils/modules/backbones에는 __init__.py가 없어, 환경에 같은 이름의 패키지가 설치돼 있으면
# 그쪽이 먼저 잡힌다. 현재 폴더(OpenDPD 루트)의 것을 강제로 쓰도록 등록한다.
for _pkg in ("utils", "modules", "backbones"):
    _m = types.ModuleType(_pkg)
    _m.__path__ = [os.path.join(os.getcwd(), _pkg)]
    sys.modules[_pkg] = _m
import models  # noqa: E402
from modules.data_collector import load_dataset  # noqa: E402
from utils import metrics  # noqa: E402
from utils.util import set_target_gain  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pa", required=True)
    ap.add_argument("--dataset", default="DPA_200MHz")
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()

    spec = json.load(open(os.path.join("datasets", a.dataset, "spec.json")))
    X_train, y_train, _, _, X_test, _ = load_dataset(a.dataset)
    gt = set_target_gain(X_train, y_train) * X_test          # run_dpd.py와 같은 기준

    pa = models.CoreModel(input_size=2, hidden_size=8, num_layers=1, backbone_type="dgru")
    pa.load_state_dict(torch.load(a.pa, map_location="cpu"))
    pa.eval()

    seg = int(spec["nperseg"])
    rows = []
    for f in a.files:
        d = np.loadtxt(f)
        # PA 대리모델(DGRU)의 FEx는 I/|x|를 계산하므로 입력이 정확히 0이면 NaN이 된다.
        # 낮은 비트폭에서는 DPD 출력이 0으로 잘리는 샘플이 생기므로 아주 작은 값으로 바꿔 평가한다.
        zero = np.all(d == 0, axis=1)
        if zero.any():
            d = d.copy()
            d[zero, 0] = 1e-9
            print(f"note: {os.path.basename(f)}: 출력이 정확히 0인 샘플 {int(zero.sum())}개 → 1e-9로 대체 (PA 모델의 0/0 방지)")
        n = len(d) // seg * seg
        if n == 0:
            print(f"{f}: {len(d)} samples < nperseg {seg}, skipped")
            continue
        # OpenDPD 학습 로그와 같은 방식: nperseg 구간으로 잘라 구간마다 PA 상태 0에서 시작, 구간별 스펙트럼 평균
        with torch.no_grad():
            y = pa(torch.tensor(d[:n].reshape(-1, seg, 2), dtype=torch.float32)).numpy()
        g = gt[:n].reshape(-1, seg, 2)
        r = {
            "NMSE": metrics.NMSE(y, g),
            # train_funcs.py:94 버그 수정: sample_rate를 spec에서 넘김
            "EVM": metrics.EVM(y, g, sample_rate=spec["input_signal_fs"], bw_main_ch=spec["bw_main_ch"],
                               n_sub_ch=spec["n_sub_ch"], nperseg=spec["nperseg"]),
        }
        r["ACPR_L"], r["ACPR_R"] = metrics.ACLR(y, fs=spec["input_signal_fs"], nperseg=spec["nperseg"],
                                                bw_main_ch=spec["bw_main_ch"], n_sub_ch=spec["n_sub_ch"])
        rows.append((f, n, r))

    base = rows[0][2]
    print(f"{'file':45s} {'T':>5s} {'NMSE':>8s} {'EVM':>8s} {'ACPR_L':>8s} {'ACPR_R':>8s}   Δ vs first")
    for f, n, r in rows:
        dl = "  ".join(f"{k}{r[k] - base[k]:+.2f}" for k in ("NMSE", "ACPR_L", "ACPR_R"))
        print(f"{os.path.basename(f):45s} {n:5d} {r['NMSE']:8.2f} {r['EVM']:8.2f} {r['ACPR_L']:8.2f} {r['ACPR_R']:8.2f}   {dl}")


if __name__ == "__main__":
    main()
