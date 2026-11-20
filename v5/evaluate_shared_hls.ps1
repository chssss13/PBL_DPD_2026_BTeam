param(
    [Parameter(Mandatory)][ValidateSet('layer2','all')][string]$Scope,
    [string]$Python = 'C:/Project/venv_dpd/Scripts/python.exe',
    [string]$Hls = 'C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat',
    [int]$TrainingProcessId = 0
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$trained = "build/v5_${Scope}_100"
if ($TrainingProcessId -and (Get-Process -Id $TrainingProcessId -ErrorAction SilentlyContinue)) {
    Wait-Process -Id $TrainingProcessId
}
if (!(Test-Path (Join-Path $trained 'validation.json'))) { throw 'Training evaluation did not complete' }
$run = "v5/prj_shared_$Scope"
$golden = Join-Path $run 'trained100_golden'
& $Python v5/export_shared_weights.py (Join-Path $trained 'dpd.pt') $golden
if ($LASTEXITCODE -ne 0) { throw 'Weight export failed' }
$env:SHARED_SCOPE = $Scope
$env:SHARED_GOLDEN = (Resolve-Path $golden).Path
$env:SHARED_PROJECT = 'trained100'
$env:SHARED_CSIM_ONLY = '1'
& $Hls -f v5/shared_hls.tcl
if ($LASTEXITCODE -ne 0) { throw 'Fixed-point C-sim failed' }
$output = (Resolve-Path (Join-Path $run 'trained100_out.txt')).Path
$eval = (Resolve-Path 'v1/tools/eval_pa.py').Path
$report = Join-Path (Resolve-Path $run).Path 'trained100_pa.txt'
Push-Location 'v1/opendpd_min'
try {
    $pa = Get-ChildItem 'save/DPA_200MHz/train_pa' -Filter '*.pt'
    $env:PYTHONIOENCODING = 'utf-8'
    & $Python $eval --pa $pa.FullName $output | Out-File -Encoding utf8 $report
    if ($LASTEXITCODE -ne 0) { throw 'PA evaluation failed' }
} finally { Pop-Location }
