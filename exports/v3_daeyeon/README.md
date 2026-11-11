# v3_daeyeon - E24 source distribution

This GitHub distribution contains the verified E24 model sources, testbench, flow scripts, source hashes, and the explanatory report. The model is identical to the full v3_daeyeon distribution saved on the owner's Desktop.

Weights, input vectors, reference outputs, native implementation reports, and checkpoints are intentionally excluded from this GitHub commit. The full local Desktop distribution retains them. This is a source distribution, not a complete public dataset archive.

## Results (previously measured)

II=2, WNS +0.056ns at a 15ns constraint, LUT 41,385, FF 41,105, DSP 362, BRAM/URAM 0/0. C-sim and RTL co-sim each matched 7,680 samples in Q12. These are recorded core OOC results, not a new run or board measurements. E24 did not demonstrate meaningful resource savings.

All in-flight calls must complete before any weight, bias, gating, or PReLU coefficient changes. See OPERATION_COMPARISON.md for the original DATAFLOW behavior and intended STABLE optimization.

## Reproduction

1. Copy the folder to a short path without spaces, for example C:/PBL_build/v3_daeyeon.
2. Verify the distributed files with `py scripts/verify.py --package`.
3. Copy `golden/` and `reference/` from the full local Desktop v3_daeyeon distribution into this folder. They are required by the testbench and comparisons, but are not included in this GitHub source distribution.
4. With Vitis HLS/Vivado 2024.1 and Python 3 installed, run `py launch_background.py`.

The worker runs C-sim, HLS (requires II=2), RTL co-sim, IP export, and P&R with Explore and AggressiveExplore. No polling or progress tracker is installed. Final results are written to RESULTS.md/evaluation.json; recorded local results are preserved separately. Tool paths can be overridden with PBL_HLS/PBL_VIVADO; E24_WORK_DIR selects a build path without spaces. Default tool paths are C:/Xilinx/Vitis_HLS/2024.1 and C:/Xilinx/Vivado/2024.1.
