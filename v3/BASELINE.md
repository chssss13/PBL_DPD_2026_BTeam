# v3 baseline

Original sehyeon v2 final, imported unchanged. Active candidate: [v3.1 FEx mixed precision](docs/v3.1_fex_mixed_precision.md). The rejected activation-symmetry candidate was actually deleted. The baseline itself is not being re-synthesized.

- Commit: a1998bd42440256687f262e53eea879257515f4a
- Original path: v2/result/final
- Local original files: src/, tb/, golden/, reference/, scripts/, reports/, logs/, changes/
- 98 original file hashes verified unchanged. See IMPORT_ORIGIN.json.
- II=2, target 15ns, imported routed comparison period 14.907ns.
- WNS +0.093ns, WHS +0.037ns.
- LUT 41,387; FF 41,088; DSP 362; BRAM 0.
- PA NMSE -44.97dB, ACPR L/R -53.35/-50.08dBc (imported measurements).
- Original full 7680-sample RTL validation retained in reports/.

Local experiment series 01-14, D01-D04, and the unintended sehyeon v3.3/R00-R02 restart were removed from the workspace. The latter process tree was terminated. Only the explicitly requested new v3.1 candidate is running; its mandatory requirements are II=2 and 15ns.

[Original instructions](README.md) | [Original reports](reports/)
