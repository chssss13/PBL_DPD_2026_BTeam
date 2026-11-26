"""Evaluate v4.7 and gate changes with unchanged deployment coefficients."""
import argparse
from pathlib import Path
import re
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "v2/tools"
sys.path.insert(0, str(TOOLS))
from hw_ref import make_q

V4 = ROOT / "v4/result"
SRC = V4 / "v4.2/fullrom_fc21/src"
GOLDEN = V4 / "v4.1/golden"
DATA = ROOT / "v1/opendpd_min"
QD, QW, QA, QOUT, QBIAS = map(make_q, ("15,3", "14,4", "18,3", "21,6", "16,4"))


def table(header, name):
    source = (SRC / header).read_text()
    values = re.search(rf"\b{name}\[\d+\]\s*=\s*\{{([^}}]+)\}}", source)[1]
    return np.fromstring(values.replace("\n", " "), sep=",", dtype=np.int64)


def wrap(value, width):
    sign = 1 << (width - 1)
    return (value + sign) % (2 * sign) - sign


def activation(values, packed, sigmoid):
    position = np.rint(values * 4096).astype(np.int64) + 16384
    index, fraction = position // 128, position % 128
    address = np.where(index < 128, 127 - index, index - 128) if sigmoid else index
    item = packed[address]
    base, delta = wrap(item & 32767, 15), item >> 15
    if sigmoid:
        base = np.where(index < 128, 4096 - base - delta, base)
    return (base + ((delta * fraction + 64) % 32768) // 128) / 4096


def mac(weights, values, quantize, wide=False, recurrent=False):
    products = weights * values
    if recurrent:
        products = wrap(np.floor(products * 32768 + 0.5).astype(np.int64), 18) / 32768
    else:
        products = quantize(products)
    if wide:
        return quantize(products.sum(axis=1))
    acc = np.zeros(weights.shape[0])
    for term in products.T:
        acc = quantize(acc + term)
    return acc


def run(iq, w, mode):
    rom = table("fex_inverse_rom.h", "fex_inverse_rom")
    sig = table("activation_interp.h", "sigmoid")
    tanh = table("activation_interp.h", "tanh")
    hidden = np.zeros((3, 5))
    out = np.empty_like(iq)
    for t, (i, q) in enumerate(QD(iq)):
        if t % 2560 == 0:
            hidden.fill(0)
        power = QD(i*i + q*q)
        inverse = rom[int(power * 4096) & 16383] / 2048
        amp = QD(power * inverse)
        f = np.array([i, q, amp, QD(amp * power), QD(q * inverse), QD(i * inverse)])
        p = QA(mac(w["W_inj"], f, QA) + w["b_inj"])
        x = QD(np.where(p > 0, p, p * w["prelu"][0]))
        for layer, prev in enumerate(hidden):
            g = w["layers"][layer]
            input_only = mode == "input_only"
            shared = mode == "share_all" or (mode == "share_layer2" and layer == 1)

            def input_term(gate):
                return mac(g[f"W_i{gate}"], x, QA, wide=True)

            def recurrent_term(gate):
                return mac(g[f"W_h{gate}"], prev, QA, wide=True, recurrent=True)

            def gate_value(gate):
                pre = input_term(gate) + QBIAS(g[f"b_i{gate}"] + g[f"b_h{gate}"])
                if not input_only:
                    pre += recurrent_term(gate)
                return activation(QD(pre), sig, True)

            z = gate_value("z")
            r = z if shared else gate_value("r")
            base = input_term("n") + g["b_in"]
            if input_only:
                base = QBIAS(base)
            n = activation(QD(base + QD(r * (recurrent_term("n") + g["b_hn"]))), tanh, False)
            hidden[layer] = QD(n + z * (prev - n))
            x = QD(hidden[layer] + w["gating"][layer] * x)
        out[t] = QD(mac(w["W_out"], x, QOUT) + w["b_out"])
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    output = parser.parse_args().output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    w = {}
    for file in (GOLDEN / "weights").glob("*.txt"):
        name = file.stem
        is_bias = name.startswith("b_") or "_b_" in name
        w[name] = (QD if is_bias else QW)(np.loadtxt(file, ndmin=1))
    w["W_inj"] = w["W_inj"].reshape(5, 6)
    w["W_out"] = w["W_out"].reshape(2, 5)
    w["layers"] = [
        {name[3:]: (value.reshape(5, 5) if name[3:].startswith("W_") else value)
         for name, value in w.items() if name.startswith(f"L{layer}_")}
        for layer in range(3)
    ]
    iq = np.loadtxt(GOLDEN / "vectors/dpd_in.txt")
    if iq.shape != (7680, 2):
        raise ValueError(f"Expected 7680 I/Q samples, got {iq.shape}")
    files = []
    for mode in ("v47", "input_only", "share_layer2", "share_all"):
        target = output / f"{mode}.txt"
        np.savetxt(target, run(iq, w, mode), fmt="%.12f")
        files.append(target)
    checkpoint, = (DATA / "save/DPA_200MHz/train_pa").glob("*.pt")
    subprocess.run([sys.executable, str(ROOT / "v1/tools/eval_pa.py"),
                    "--pa", str(checkpoint), *map(str, files)], cwd=DATA, check=True)


if __name__ == "__main__":
    main()
