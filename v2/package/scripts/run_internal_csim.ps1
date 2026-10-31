$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$env:STEPS = 'csim'
$env:NT = '7680'
$env:FEX_INTERNAL_FIXED = '1'
$env:ACT_LUT = '0' # Candidates A/B retain the double-math activation reference.
foreach ($invBits in @(3, 8)) {
    $env:FEX_INV_I = "$invBits"
    $experiment = "results/fex_comparison/csim/invI$invBits"
    New-Item -ItemType Directory -Path "$experiment/src" -Force | Out-Null
    Copy-Item src/* "$experiment/src"
    Copy-Item scripts/run_resgru.tcl "$experiment/run_resgru.tcl"
    Copy-Item tb/tb_resgru.cpp "$experiment/tb_resgru.cpp"
    "START C-sim inverse integer bits = $invBits"
    & C:\Xilinx\Vitis_HLS\2024.1\bin\vitis_hls.bat -f scripts/run_resgru.tcl *> "$experiment/csim.log"
    if ($LASTEXITCODE -ne 0) { throw "C-sim failed: $experiment/csim.log" }
    Copy-Item results/hls_out.txt "$experiment/hls_out.txt"
    "DONE C-sim inverse integer bits = $invBits"
}
