@echo off
setlocal
cd /d "%~dp0.."
set STEPS=csim csynth
set NT=7680
set ACT_LUT=2
set FEX_INTERNAL_FIXED=1
set FEX_INV_I=8
set DSP_FULL_REG=false
set TARGET_II=2
set CLOCK_UNCERTAINTY_NS=1.0
for %%S in (3 2) do (
    set DIRECT_LUT_SHIFT=%%S
    set HLS_PROJECT=prj_lut_density_%%S
    call :run_case %%S
    if errorlevel 1 exit /b 1
)
exit /b 0
:run_case
if not exist results\lut_density\shift%1 mkdir results\lut_density\shift%1
set HLS_OUTPUT=%CD%\results\lut_density\shift%1\hls_out.txt
call vitis_hls -f scripts/run_resgru.tcl > results\lut_density\shift%1\hls.log 2>&1
exit /b %errorlevel%
