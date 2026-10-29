"""LW-ResGRU HLS 구조를 그대로 따라 하는 numpy 참조 모델 (torch 불필요).

HLS ResGRU (LW-ResGRU_HLS/multi_gru.cpp)와 같은 순서로 계산합니다.
    FEx → W_inj·x + b_inj → PReLU → [GRU_n → x = h + σ(S_n)·x] × L → W_out·x + b_out

옵션으로 HLS의 근사를 하나씩 켜고 끌 수 있어서, 각 근사가 정확도에 주는 영향을 따로 잴 수 있습니다.
    --act  exact | hard          sigmoid/tanh 정확값 | v0 HLS의 my_hard_sigmoid / my_hard_tanh
                                 (다른 근사를 쓰려면 sigmoid() / tanh() 와 run_fxp() 안의 sig() / th()에
                                  여러분의 HW와 같은 계산을 추가하세요)
    --fex  exact | nr | nr_fx    정확값 | HLS의 테일러+NR 4회(float) | 같은 식을 ap_fixed<16,2> 포화까지 흉내
    --reset_every N              N샘플마다 은닉 상태 0으로 리셋. 기본값은 golden의 segment_len(2560)으로
                                 PyTorch golden과 같은 조건. HLS 원본 동작은 64, 0이면 리셋 없음

PTQ(사후 양자화) 시뮬레이션 — HLS의 ap_fixed 연산을 흉내 냅니다.
    --data_t W,I     활성화·층 사이 값·bias (HLS data_t)
    --weight_t W,I   가중치·σ(S_n)·PReLU α (HLS weight_t)
    --accum_t W,I    행렬곱 누산기 (HLS accum_t)
    --fxp hls        위 셋을 HLS baseline 값으로: data_t 16,2 / weight_t 16,2 / accum_t 18,3
  ap_fixed<W,I,AP_RND,AP_SAT>와 같이 반올림(동점은 +쪽)하고 포화합니다. HLS 코드에서 값이 해당 타입
  변수에 대입되는 지점마다 같은 순서로 양자화하므로, 같은 근사(--act, --fex)를 쓰면 HLS C-sim과
  거의 같은 값이 나와야 합니다 (bit-exact 여부는 C-sim과 비교해 확인).
  셋 중 일부만 주면 나머지는 float로 계산합니다 (어느 타입이 손실을 만드는지 분리할 때).

예:
    python tools/hw_ref.py --golden golden --out ref_exact.txt --ref golden/vectors/torch_out_wq.txt
    python tools/hw_ref.py --golden golden --fxp hls --out ref_ptq16.txt
    python tools/hw_ref.py --golden golden --data_t 12,2 --weight_t 12,2 --accum_t 14,3 --out ref_ptq12.txt
"""
import argparse
import json
import os

import numpy as np
DIRECT_LUT_SCALE = 512.0


def load_weights(wdir):
    man = json.load(open(os.path.join(wdir, "manifest.json")))
    w = {}
    for k, v in man.items():
        if k.startswith("_"):
            continue
        w[k] = np.loadtxt(os.path.join(wdir, k + ".txt"), ndmin=1).reshape(v["shape"])
    return w, man["_config"]


def q16_2(v):
    """ap_fixed<16,2,AP_RND,AP_SAT> 근사: 소수 14비트 반올림, [-2, 2) 포화."""
    return np.clip(np.round(np.asarray(v) * 2 ** 14) / 2 ** 14, -2.0, 2.0 - 2 ** -14)


def make_q(spec):
    """'W,I' → ap_fixed<W,I,AP_RND,AP_SAT> 양자화 함수. None이면 항등 함수."""
    if spec is None:
        return lambda v: v
    W, I = (int(s) for s in spec.split(","))
    F = W - I
    lo, hi = -(2.0 ** (I - 1)), 2.0 ** (I - 1) - 2.0 ** -F
    s = 2.0 ** F
    return lambda v: np.clip(np.floor(np.asarray(v, dtype=np.float64) * s + 0.5) / s, lo, hi)


def fex(I, Q, mode):
    if mode == "exact":
        amp = np.sqrt(I * I + Q * Q)
        inv = np.where(amp > 0, 1.0 / np.where(amp > 0, amp, 1), 0.0)
        return np.array([I, Q, amp, amp ** 3, Q * inv, I * inv])
    qf = q16_2 if mode == "nr_fx" else (lambda v: v)
    amp2 = qf(I * I + Q * Q)
    delta = qf(amp2 - 1)
    inv = qf(1 - 0.5 * delta + 0.375 * delta * delta)       # linear_layer.h:62
    for _ in range(4):                                       # linear_layer.h:65-67
        inv = qf(inv * (1.5 - 0.5 * amp2 * inv * inv))
    amp = qf(amp2 * inv)
    return np.array([I, Q, amp, qf(amp * amp2), qf(Q * inv), qf(I * inv)])


def sigmoid(x, mode):
    if mode == "lut":
        return activation_lut(x, False)
    if mode == "exact":
        return 1 / (1 + np.exp(-x))
    return np.clip(0.2 * x + 0.5, 0.0, 1.0)


def tanh(x, mode):
    if mode == "lut":
        return activation_lut(x, True)
    if mode == "exact":
        return np.tanh(x)
    return np.clip(x, -1.0, 1.0)


def activation_lut(x, is_tanh):
    # Mirrors activation_lut.h: abs, round index, table, restore symmetry.
    v = np.asarray(x)
    index = np.clip(np.floor(np.abs(v) * 512.0 + 0.5), 0, 2048).astype(int)
    grid = index / 512.0
    value = np.tanh(grid) if is_tanh else 1 / (1 + np.exp(-grid))
    value = np.floor(value * 8192.0 + 0.5) / 8192.0
    return np.where(v < 0, -value if is_tanh else 1 - value, value)


def run(w, cfg, x_iq, act="exact", fex_mode="exact", reset_every=0, dump=None):
    H, L = cfg["H"], cfg["L"]
    T = len(x_iq)
    h = np.zeros((L, H))
    y = np.zeros((T, 2))
    mids = {k: [] for k in ("fex", "prelu", *[f"layer{n}" for n in range(L)])} if dump else None
    for t in range(T):
        if reset_every and t % reset_every == 0:
            h[:] = 0
        f = fex(x_iq[t, 0], x_iq[t, 1], fex_mode)
        p = w["W_inj"] @ f + w["b_inj"]
        x = np.where(p >= 0, p, w["prelu"][0] * p)
        if dump:
            mids["fex"].append(f)
            mids["prelu"].append(x)
        for n in range(L):
            r = sigmoid(w[f"L{n}_W_ir"] @ x + w[f"L{n}_b_ir"] + w[f"L{n}_W_hr"] @ h[n] + w[f"L{n}_b_hr"], act)
            z = sigmoid(w[f"L{n}_W_iz"] @ x + w[f"L{n}_b_iz"] + w[f"L{n}_W_hz"] @ h[n] + w[f"L{n}_b_hz"], act)
            nn_ = tanh(w[f"L{n}_W_in"] @ x + w[f"L{n}_b_in"] + r * (w[f"L{n}_W_hn"] @ h[n] + w[f"L{n}_b_hn"]), act)
            h[n] = (1 - z) * nn_ + z * h[n]
            x = h[n] + w["gating"][n] * x
            if dump:
                mids[f"layer{n}"].append(x.copy())
        y[t] = w["W_out"] @ x + w["b_out"]
    if dump:
        save_dump(dump, mids)
    return y


def run_fxp(w, cfg, x_iq, qd, qw, qa, act="exact", fex_mode="exact", reset_every=0, dump=None):
    """HLS ResGRU의 고정소수점 동작을 흉내. qd/qw/qa = data_t/weight_t/accum_t 양자화 함수.

    양자화 지점은 HLS 소스에서 해당 타입 변수에 대입되는 곳과 같습니다.
      MAC_PE (linear_layer.h:12)   acc += accum_T(x*w)  → 곱마다 accum, 누적마다 accum
      Linear W_inj (multi_gru.cpp:315)  y = MAC + b   → accum_t
      PReLU (activations.h:67)     out = data_t(in) 또는 data_t(in*α)
      Gate_Calc_PE (gru_cell.h:94) r_pre, z_pre, n_pre, r_h, r, z, n, 1-z, h_next 모두 data_T
      잔차 (multi_gru.cpp:343)     data_t(h + g*x)
      출력 Linear (multi_gru.cpp:350)  누산 타입이 data_t
    """
    H, L = cfg["H"], cfg["L"]
    W = {k: (qd(v) if k.startswith("b_") or "_b_" in k else qw(v)) for k, v in w.items()}
    c02, c05, one = qd(0.2), qd(0.5), qd(1.0)

    def mac(Wm, x, q):                    # Wm: (out, in)
        acc = np.zeros(Wm.shape[0])
        for i in range(Wm.shape[1]):
            acc = q(acc + q(Wm[:, i] * x[i]))
        return acc

    def sig(v):
        if act == "lut_direct":
            grid = np.floor(v * DIRECT_LUT_SCALE) / DIRECT_LUT_SCALE + 0.5/DIRECT_LUT_SCALE
            return qd(1 / (1 + np.exp(-grid)))
        if act == "lut":
            return qd(activation_lut(v, False))
        if act == "exact":
            return qd(1 / (1 + np.exp(-v)))
        return np.clip(qd(c02 * v + c05), 0.0, 1.0)

    def th(v):
        if act == "lut_direct":
            grid = np.floor(v * DIRECT_LUT_SCALE) / DIRECT_LUT_SCALE + 0.5/DIRECT_LUT_SCALE
            return qd(np.tanh(grid))
        if act == "lut":
            return qd(activation_lut(v, True))
        if act == "exact":
            return qd(np.tanh(v))
        return np.clip(v, -1.0, 1.0)

    T = len(x_iq)
    xq = qd(x_iq)                          # testbench: data_t(i), data_t(q)
    h = np.zeros((L, H))
    y = np.zeros((T, 2))
    mids = {k: [] for k in ("fex", "prelu", *[f"layer{n}" for n in range(L)])} if dump else None
    for t in range(T):
        if reset_every and t % reset_every == 0:
            h[:] = 0
        f = qd(fex(xq[t, 0], xq[t, 1], fex_mode))          # FExLayer 출력은 data_T
        p = qa(mac(W["W_inj"], f, qa) + W["b_inj"])
        x = qd(np.where(p > 0, p, p * W["prelu"][0]))
        if dump:
            mids["fex"].append(f)
            mids["prelu"].append(x)
        for n in range(L):
            g = lambda k: W[f"L{n}_{k}"]  # noqa: E731
            ir, iz, in_ = mac(g("W_ir"), x, qa), mac(g("W_iz"), x, qa), mac(g("W_in"), x, qa)
            hr, hz, hn = mac(g("W_hr"), h[n], qa), mac(g("W_hz"), h[n], qa), mac(g("W_hn"), h[n], qa)
            r = sig(qd(ir + g("b_ir") + hr + g("b_hr")))
            r_h = qd(r * (hn + g("b_hn")))
            nn_ = th(qd(in_ + g("b_in") + r_h))
            z = sig(qd(iz + g("b_iz") + hz + g("b_hz")))
            omz = qd(one - z)
            h[n] = qd(omz * nn_ + z * h[n])
            x = qd(h[n] + W["gating"][n] * x)
            if dump:
                mids[f"layer{n}"].append(x.copy())
        y[t] = qd(mac(W["W_out"], x, qd) + W["b_out"])
    if dump:
        save_dump(dump, mids)
    return y


def save_dump(dump, mids):
    os.makedirs(dump, exist_ok=True)
    for k, v in mids.items():
        np.savetxt(os.path.join(dump, k + ".txt"), np.array(v), fmt="%.10f")


def nmse_db(pred, ref):
    return 10 * np.log10(max(np.sum((pred - ref) ** 2), 1e-300) / np.sum(ref ** 2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--golden", required=True, help="export_golden.py의 --out 폴더")
    ap.add_argument("--act", choices=["exact", "hard", "lut", "lut_direct"], default="exact")
    ap.add_argument("--fex", choices=["exact", "nr", "nr_fx"], default="exact")
    ap.add_argument("--reset_every", type=int, default=None)
    ap.add_argument("--fxp", choices=["hls"], help="HLS baseline 타입 일괄 지정 (16,2 / 16,2 / 18,3)")
    ap.add_argument("--data_t", help="W,I  예: 16,2")
    ap.add_argument("--weight_t", help="W,I")
    ap.add_argument("--accum_t", help="W,I")
    ap.add_argument("--n", type=int, default=0, help="앞에서 n샘플만 (0이면 전체)")
    ap.add_argument("--out", required=True)
    ap.add_argument("--ref", help="비교할 출력 파일 (T x 2)")
    ap.add_argument("--dump", help="중간 결과(fex, prelu, layerN) 저장 폴더")
    a = ap.parse_args()

    if a.fxp == "hls":
        a.data_t, a.weight_t, a.accum_t = a.data_t or "16,2", a.weight_t or "16,2", a.accum_t or "18,3"
    w, cfg = load_weights(os.path.join(a.golden, "weights"))
    if a.reset_every is None:
        a.reset_every = cfg.get("segment_len", 0)
    x = np.loadtxt(os.path.join(a.golden, "vectors", "dpd_in.txt"))
    if a.n:
        x = x[: a.n]

    fxp = any((a.data_t, a.weight_t, a.accum_t))
    if fxp:
        y = run_fxp(w, cfg, x, make_q(a.data_t), make_q(a.weight_t), make_q(a.accum_t),
                    a.act, a.fex, a.reset_every, a.dump)
        types = f", data_t={a.data_t or 'float'}, weight_t={a.weight_t or 'float'}, accum_t={a.accum_t or 'float'}"
    else:
        y = run(w, cfg, x, a.act, a.fex, a.reset_every, a.dump)
        types = ""
    np.savetxt(a.out, y, fmt="%.10f")
    print(f"saved {a.out}  (act={a.act}, fex={a.fex}, reset_every={a.reset_every}{types}, T={len(x)})")
    if a.ref:
        ref = np.loadtxt(a.ref)[: len(y)]
        print(f"NMSE vs ref: {nmse_db(y, ref):.2f} dB   max|err|: {np.max(np.abs(y - ref)):.3e}")


if __name__ == "__main__":
    main()
