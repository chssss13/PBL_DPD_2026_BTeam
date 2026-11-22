"""Fine-tune the DPD output FC against the frozen PA. Run from any directory."""
import argparse
import json
import os
import shutil
import sys
from pathlib import Path

import numpy as np
import torch
from torch import nn

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "package"
OPENDPD = PACKAGE / "opendpd_min"


def quantize(x, width, integer):
    scale = 2 ** (width - integer)
    rounded = torch.floor(x * scale + 0.5)
    fixed = rounded.clamp(-(2 ** (width - 1)), 2 ** (width - 1) - 1) / scale
    return x + (fixed - x).detach()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--epochs", type=int, default=3)
    ap.add_argument("--device", choices=("cpu", "directml"), default="cpu")
    args = ap.parse_args()
    out = args.out.resolve()
    if out.exists() or args.epochs < 1:
        ap.error("Choose a new output directory and at least one epoch.")
    os.chdir(OPENDPD)
    sys.path.insert(0, str(PACKAGE / "tools"))
    sys.path.insert(0, str(OPENDPD))
    from eval_pa import models, load_dataset, set_target_gain

    torch.set_num_threads(2)
    torch.manual_seed(4574)
    device = torch.device("cpu")
    adapter = "CPU"
    if args.device == "directml":
        import torch_directml
        for index in range(torch_directml.device_count()):
            name = torch_directml.device_name(index)
            if "amd" in name.lower() or "radeon" in name.lower():
                device = torch_directml.device(index)
                adapter = name.rstrip("\0")
                break
        else:
            ap.error("No AMD DirectML adapter detected.")
    print(f"Training device: {adapter}", flush=True)
    directory = Path("save/DPA_200MHz")
    dpd = models.CoreModel(2, 5, 3, "rgruwfex", residual_type=2)
    pa = models.CoreModel(2, 8, 1, "dgru")
    for model, sub in [(dpd, "train_dpd"), (pa, "train_pa")]:
        checkpoint, = (directory / sub).glob("*.pt")
        model.load_state_dict(torch.load(checkpoint, map_location="cpu", weights_only=True))
        model.eval().requires_grad_(False)
    head = dpd.backbone.fc_out.to(device)
    dpd.backbone.fc_out = nn.Identity()
    x, y, v, _, _, _ = load_dataset("DPA_200MHz")
    gain = float(set_target_gain(x, y))

    def frames(iq):
        inputs = torch.tensor(iq, dtype=torch.float32).reshape(-1, 2560, 2)
        with torch.no_grad():
            hidden = dpd(inputs)
        return quantize(hidden.to(device), 15, 3), inputs * gain

    train_h, target = frames(x)
    val_h, val_target = frames(v)
    head.requires_grad_(True)
    optimizer = torch.optim.Adam(head.parameters(), lr=0.00025)

    def loss(h, reference):
        w = quantize(head.weight, 14, 4)
        products = quantize(h.unsqueeze(-2) * w, 21, 6)
        acc = torch.zeros_like(products[..., 0])
        for product in products.unbind(-1):
            acc = quantize(acc + product, 21, 6)
        pred = quantize(acc + quantize(head.bias, 15, 3), 15, 3)
        zero = (pred == 0).all(-1)
        pred = pred + torch.stack((zero.float() * 1e-9, torch.zeros_like(pred[..., 0])), -1)
        # DirectML lacks the fused GRU kernel. Autograd crosses this copy.
        return (pa(pred.cpu()) - reference).square().mean() / reference.square().mean()

    with torch.no_grad():
        baseline = float(loss(val_h, val_target))
    if not np.isfinite(baseline):
        raise ValueError("Nonfinite baseline validation loss")
    best, epoch = baseline, 0
    saved = {k: a.detach().clone() for k, a in head.state_dict().items()}
    for i in range(args.epochs):
        for j in torch.randperm(len(train_h)):
            optimizer.zero_grad()
            loss(train_h[j:j+1], target[j:j+1]).backward()
            optimizer.step()
        with torch.no_grad():
            score = float(loss(val_h, val_target))
        if score < best:
            best, epoch = score, i + 1
            saved = {k: a.detach().clone() for k, a in head.state_dict().items()}
    head.load_state_dict(saved)
    weights = ROOT / "v4.6_final/golden/weights"
    shutil.copytree(weights, out / "weights")
    manifest = json.loads((PACKAGE / "golden/weights/manifest.json").read_text())
    for name, param in [("W_out", head.weight), ("b_out", head.bias)]:
        arr = param.detach().cpu().numpy()
        if arr.size != np.loadtxt(weights / (name + ".txt")).size:
            raise ValueError(name)
        np.savetxt(out / "weights" / (name + ".txt"), arr.reshape(-1), fmt="%.10f")
        manifest[name].update(min=float(arr.min()), max=float(arr.max()))
    (out / "weights/manifest.json").write_text(json.dumps(manifest, indent=2))
    report = dict(device=adapter, selected_epoch=epoch, val_baseline_nmse_db=10*np.log10(baseline),
                  val_selected_nmse_db=10*np.log10(best), hidden_model="floating point DPD")
    (out / "validation.json").write_text(json.dumps(report, indent=2))
    print(report)


if __name__ == "__main__":
    main()
