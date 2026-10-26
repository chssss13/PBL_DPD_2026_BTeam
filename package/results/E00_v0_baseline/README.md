# E00: v0 baseline reproduction

## Environment

- Windows, Vitis HLS / Vivado 2024.1
- Device: xczu7ev-ffvc1156-2-e
- Target clock: 15 ns
- Implementation completed: 2026-10-17 02:45 KST
- Design: original v0, H=5, L=3, TIME_STEP=64
- data_t / weight_t: ap_fixed<16,2,AP_RND,AP_SAT>
- accum_t: ap_fixed<18,3,AP_RND,AP_SAT>

## Verification

Results below were recorded from the completed commands in the project session.

| Comparison | Samples | NMSE | Maximum absolute error | Result |
|---|---:|---:|---:|---|
| Exact Python reference vs PyTorch golden | 7,680 | -138.00 dB | 1.957e-07 | Meets -100 dB criterion |
| HLS C-sim vs v0 Python reference | 7,680 | -82.66 dB | 2.441e-04 | PASS (limit -60 dB) |

The second comparison is not bit-exact (7,647 mismatching samples). PA-passed NMSE/EVM/ACPR have not yet been measured in this experiment. Reference-comparison NMSE is not PA-passed NMSE.

## C synthesis and implementation

| Metric | Value |
|---|---:|
| HLS estimated clock period | 10.912 ns |
| Top latency (64 samples) | 157 cycles / 2.355 us at 15 ns |
| Top interval | 128 cycles |
| LOOP_T II / pipeline depth | 2 / 26 cycles |
| Post-route LUT / FF | 46,646 / 49,546 |
| Post-route DSP / BRAM / URAM | 648 / 0 / 0 |
| Post-route period | 17.129 ns |
| Setup WNS | -2.128608 ns |
| Timing target | NOT MET |
| Estimated throughput from post-route period and II | 29.2 MSps |

Throughput is calculated, not measured on an FPGA board. Implementation completed successfully as a tool run, but failed the 15 ns timing target.

## Reproduce

Run from `package` in Vitis HLS 2024.1 Command Prompt with the Python environment activated:

```bat
set STEPS=csim
vitis_hls -f scripts/run_resgru.tcl
python tools/hw_ref.py --golden golden --out results/ref_exact.txt --ref golden/vectors/torch_out.txt
python tools/hw_ref.py --golden golden --fxp hls --act hard --fex nr_fx --reset_every 64 --out results/ref_v0.txt
python tools/compare_out.py results/hls_out.txt results/ref_v0.txt --nmse_max -60
set STEPS=csynth
vitis_hls -f scripts/run_resgru.tcl
vitis_hls -f scripts/run_impl_existing.tcl
```

`run_resgru.tcl` resets the generated project. `run_impl_existing.tcl` reuses the current synthesis results. Generated projects and local environments are excluded from Git. The reports and three output vectors in this folder preserve the baseline evidence; the v0 design sources remain tracked under `package/src`.
