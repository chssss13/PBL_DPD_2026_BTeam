"""Week 9 paired float and fixed-point-aware DPD fine-tuning."""
import argparse
import json
import os
from pathlib import Path
import sys
import time

import numpy as np
import torch

from evaluate_v47_hw_ref import ROOT, table

DATA = ROOT / "v1/opendpd_min"
SCOPES = ("share_layer2", "share_all", "fastgrnn", "input23", "input123")


def quant(x, width, frac, enabled, wrap=False):
    if not enabled:
        return x
    scale, bound = 2**frac, 2**(width - 1)
    code = torch.floor(x.detach() * scale + .5)
    code = (code + bound).remainder(2 * bound) - bound if wrap else code.clamp(-bound, bound - 1)
    exact = code / scale
    return exact + (x - x.detach())


def tables():
    rom = torch.tensor(table("fex_inverse_rom.h", "fex_inverse_rom")) / 2048
    position = np.arange(32768)
    index, fraction = position // 128, position % 128
    result = [rom]
    for name in ("sigmoid", "tanh"):
        sig = name == "sigmoid"
        values = table("activation_interp.h", name)
        address = np.where(index < 128, 127-index, index-128) if sig else index
        packed = values[address]
        base, delta = ((packed & 32767) + 16384) % 32768 - 16384, packed >> 15
        if sig:
            base = np.where(index < 128, 4096-base-delta, base)
        result.append(torch.tensor((base + ((delta*fraction+64) % 32768)//128) / 4096))
    return result


class Candidate(torch.nn.Module):
    def __init__(self, original, scope, scratch=False):
        super().__init__()
        self.scope = scope
        self.scratch = scratch
        self.p = torch.nn.ParameterDict()
        self.rom, self.sig, self.tanh = tables()
        # Copy the original tensors by their semantic names, including residual logits.
        for key, value in original.state_dict().items():
            self.p[key.replace(".", "_")] = torch.nn.Parameter(value.detach().clone())
        if scope == "fastgrnn":
            for layer in range(3):
                prefix = f"backbone_rnn_rnn_layers_{layer}_"
                for base, name in (("weight_ih_l0", "W"), ("weight_hh_l0", "U")):
                    self.p[f"{prefix}{name}"] = torch.nn.Parameter(self.p[prefix+base].detach().chunk(3)[2].clone())
                for index, gate in ((1, "bz"), (2, "bn")):
                    inputs = self.p[prefix+"bias_ih_l0"].detach().chunk(3)[index]
                    recurrent = self.p[prefix+"bias_hh_l0"].detach().chunk(3)[index]
                    self.p[prefix+gate] = torch.nn.Parameter((inputs + recurrent).clone())
                self.p[prefix+"zeta"] = torch.nn.Parameter(torch.tensor(1.0))
                self.p[prefix+"nu"] = torch.nn.Parameter(torch.tensor(0.0))

                if scratch:
                    torch.nn.init.xavier_uniform_(self.p[prefix+"W"])
                    torch.nn.init.orthogonal_(self.p[prefix+"U"])
                    torch.nn.init.zeros_(self.p[prefix+"bz"])
                    torch.nn.init.zeros_(self.p[prefix+"bn"])
                    torch.nn.init.constant_(self.p[prefix+"zeta"], torch.logit(torch.tensor(0.75)).item())
                    torch.nn.init.constant_(self.p[prefix+"nu"], torch.logit(torch.tensor(0.125)).item())

    def forward(self, iq, fixed):
        p = self.p
        dtype = torch.float64 if fixed else torch.float32
        iq = iq.to(dtype)
        def q(x, w=15, f=12, wrap=False):
            return quant(x, w, f, fixed, wrap)
        def coeff(x):
            return q(x.to(dtype), 14, 10)
        def bias(x):
            return q(x.to(dtype))
        def normal(x, table, fn):
            y = fn(x)
            if not fixed:
                return y
            code = (x.detach() * 4096).to(torch.int64) + 16384
            return table[code] + (y-y.detach())
        def mac(x, w, wide=True, recur=False, out=False):
            if not fixed:
                return x @ w.T
            bits = 21 if out else 18
            products = q(x.unsqueeze(-2)*w, bits, 15, recur)
            if wide:
                return q(products.sum(-1), bits, 15)
            acc = torch.zeros_like(products[..., 0])
            for term in products.unbind(-1):
                acc = q(acc+term, bits, 15)
            return acc

        iq = q(iq)
        power = iq.square().sum(-1, keepdim=True)
        if fixed:
            power = q(power)
            inv = self.rom[(power.detach().mul(4096).to(torch.int64) & 16383)]
            amp = q(power*inv)
            cubic = q(amp*power)
            normalized = q(iq*inv)
        else:
            amp = power.clamp_min(1e-18).sqrt()
            cubic = amp*power
            normalized = iq/amp
        x = torch.cat((iq,amp,cubic,normalized.flip(-1)),dim=-1)
        x = q(mac(x, coeff(p["backbone_W_in_weight"]), wide=False) +
              bias(p["backbone_W_in_bias"]),18,15)
        x = q(torch.where(x>0,x,x*coeff(p["backbone_in_act_alpha"])))
        gates = [coeff(p[f"backbone_rnn_gates_{layer}"].sigmoid()) for layer in range(3)]
        for layer in range(3):
            k = f"backbone_rnn_rnn_layers_{layer}_"
            wi = coeff(p[k+"weight_ih_l0"]).chunk(3)
            wh = coeff(p[k+"weight_hh_l0"]).chunk(3)
            bi = bias(p[k+"bias_ih_l0"]).chunk(3)
            bh = bias(p[k+"bias_hh_l0"]).chunk(3)
            state = x.new_zeros((len(x),5))
            steps = []
            ino = self.scope == "input123" or (self.scope == "input23" and layer > 0)
            share = self.scope == "share_all" or (self.scope == "share_layer2" and layer == 1)
            if self.scope == "fastgrnn":
                terms = mac(x, coeff(p[k+"W"]))
                u, zeta, nu = (coeff(p[k+n]) for n in ("U","zeta","nu"))
                if self.scratch:
                    zeta, nu = (coeff(p[k+n].sigmoid()) for n in ("zeta","nu"))
                bz, bn = (bias(p[k+name]) for name in ("bz", "bn"))
                for term in terms.unbind(1):
                    mix = q(term+mac(state,u),19,15)
                    z = normal(q(mix+bz), self.sig, torch.sigmoid)
                    n = normal(q(mix+bn), self.tanh, torch.tanh)
                    scaled = q(zeta*n,26,22)
                    state = q(q(scaled+q(nu*n,26,22)+z*(state-scaled),41,34))
                    steps.append(state)
            else:
                terms = [mac(x,m) for m in wi]
                bz, br = q(bi[1]+bh[1],16,12), q(bi[0]+bh[0],16,12)
                for ir, iz, candidate in zip(*(term.unbind(1) for term in terms)):
                    z = normal(q(iz+bz+(0 if ino else mac(state,wh[1],recur=True))), self.sig, torch.sigmoid)
                    r = z if share else normal(q(ir+br+(0 if ino else mac(state,wh[0],recur=True))), self.sig, torch.sigmoid)
                    base = q(candidate+bi[2],16,12,True) if ino else candidate+bi[2]
                    n = normal(q(base+q(r*(mac(state,wh[2],recur=True)+bh[2]))), self.tanh, torch.tanh)
                    state = q(n+z*(state-n),wrap=True)
                    steps.append(state)
            x = q(torch.stack(steps,dim=1)+gates[layer]*x)
        return q(mac(x,coeff(p["backbone_fc_out_weight"]),wide=False,out=True)
                 +bias(p["backbone_fc_out_bias"])).float()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scope",choices=(*SCOPES, "original"))
    parser.add_argument("mode",choices=("float","qat"))
    parser.add_argument("output",type=Path)
    parser.add_argument("--epochs",type=int,default=100)
    parser.add_argument("--stride",type=int,default=50)
    parser.add_argument("--scratch", action="store_true", help="Use the original 100-epoch FP32 training protocol with fresh initialization.")
    parser.add_argument("--loader-shuffle", action="store_true",
                        help="Use shuffled PyTorch DataLoader batches for a scratch reproduction trial.")
    args = parser.parse_args()
    if args.loader_shuffle and not args.scratch:
        parser.error("--loader-shuffle requires --scratch")
    if args.scratch and args.mode != "float":
        parser.error("--scratch requires float mode")
    output = args.output.resolve()
    output.mkdir(parents=True)
    os.chdir(DATA)
    sys.path.insert(0,str(ROOT/"v1/tools"))
    from eval_pa import load_dataset, models, set_target_gain, metrics
    torch.manual_seed(4574)
    torch.set_num_threads(2)
    original = models.CoreModel(2,5,3,"rgruwfex",residual_type=2)
    pa = models.CoreModel(2,8,1,"dgru")
    for m, stage in ((original,"train_dpd"),(pa,"train_pa")):
        if args.scratch and stage == "train_dpd":
            continue
        checkpoint, = (Path("save/DPA_200MHz")/stage).glob("*.pt")
        m.load_state_dict(torch.load(checkpoint,map_location="cpu",weights_only=True))
        m.eval()
    pa.requires_grad_(False)
    candidate = original if args.scratch and args.scope == "original" else Candidate(original,args.scope,args.scratch)
    lr = .001 if args.scratch else .00025
    train_x,train_y,val_x,_,test_x,_=load_dataset("DPA_200MHz")
    gain=float(set_target_gain(train_x,train_y))
    spec=json.loads(Path("datasets/DPA_200MHz/spec.json").read_text())
    seg=spec["nperseg"]
    train,val,test=[torch.as_tensor(a,dtype=torch.float32).reshape(-1,seg,2) for a in (train_x,val_x,test_x)]
    frames=train.unfold(1,50,args.stride).transpose(-1,-2).reshape(-1,50,2).contiguous()
    loader = (torch.utils.data.DataLoader(frames, batch_size=64, shuffle=True)
              if args.loader_shuffle else None)
    opt=torch.optim.AdamW(candidate.parameters(),lr=lr,weight_decay=.01)
    scheduler=torch.optim.lr_scheduler.ReduceLROnPlateau(opt,factor=.5,patience=5)
    start=time.monotonic()

    def through_pa(x):
        zero=(x==0).all(dim=-1)*1e-9
        return pa(x+torch.stack((zero,torch.zeros_like(zero)),dim=-1))

    def predict(x, fixed=False):
        if candidate is original:
            zero = (x == 0).all(dim=-1)*1e-9
            return original(x + torch.stack((zero, torch.zeros_like(zero)),dim=-1))
        return candidate(x, fixed)

    @torch.no_grad()
    def evaluate(x, fixed=True):
        y=through_pa(predict(x,fixed)).numpy()
        target=(x*gain).numpy()
        left,right=metrics.ACLR(y,fs=spec["input_signal_fs"],nperseg=seg,bw_main_ch=spec["bw_main_ch"],n_sub_ch=spec["n_sub_ch"])
        return {"nmse":float(metrics.NMSE(y,target)), "aclr_l":float(left),"aclr_r":float(right),
                "aclr_average":float((left+right)/2),
                "evm":float(metrics.EVM(y,target,sample_rate=spec["input_signal_fs"],bw_main_ch=spec["bw_main_ch"],n_sub_ch=spec["n_sub_ch"],nperseg=seg))}

    config = {
        "scope": args.scope, "mode": args.mode, "frame": 50, "stride": args.stride, "batch": 64,
        "shuffle": "pytorch_dataloader" if args.loader_shuffle else "torch_randperm",
        "frames": len(frames), "seed": 4574, "lr": lr, "epochs": args.epochs, "target_gain": gain,
        "initialization": "scratch" if args.scratch else "pretrained",
        "selection": "validation FP32 mean ACLR" if args.scratch else "validation fixed-point mean ACLR",
        "optimizer": "AdamW", "weight_decay": .01, "clip": 200, "scheduler_patience": 5,
        "lr_decay_start_epoch": 93 if args.scratch else 0,
        "early_stop_patience": None if args.scratch else 12,
        "early_stop_min_epoch": None if args.scratch else 20,
    }
    (output/"config.json").write_text(json.dumps(config,indent=2))
    if not args.scratch:
        (output/"baseline_test.json").write_text(json.dumps(evaluate(test),indent=2))
    history=[]
    best=float("inf")
    for epoch in range(args.epochs+1):
        if epoch:
            batches = loader if loader is not None else (
                frames[indices] for indices in torch.randperm(len(frames)).split(64)
            )
            for x in batches:
                opt.zero_grad()
                loss=(through_pa(predict(x,args.mode=="qat"))-x*gain).square().mean()
                if not torch.isfinite(loss):
                    raise ValueError("Nonfinite training loss")
                loss.backward()
                torch.nn.utils.clip_grad_norm_(candidate.parameters(),200,error_if_nonfinite=True)
                opt.step()
        record=evaluate(val,fixed=not args.scratch)
        record.update(epoch=epoch, lr=opt.param_groups[0]["lr"], seconds=time.monotonic()-start)
        score=record["aclr_average"]
        if not np.isfinite(score):
            raise ValueError("Nonfinite validation ACLR")
        history.append(record)
        print(json.dumps(record),flush=True)
        (output/"history.json").write_text(json.dumps(history,indent=2))
        if (epoch > 0 or not args.scratch) and score<best:
            best,best_epoch=score,epoch
            torch.save(candidate.state_dict(),output/"best.pt")
        if not args.scratch or epoch>=93:
            scheduler.step(score)
        if not args.scratch and epoch>=20 and epoch-best_epoch>=12:
            break
    candidate.load_state_dict(torch.load(output/"best.pt",weights_only=True))
    (output/"test.json").write_text(json.dumps({"best_epoch":best_epoch,"test":evaluate(test,fixed=not args.scratch),"seconds":time.monotonic()-start},indent=2))


if __name__=="__main__":
    main()
