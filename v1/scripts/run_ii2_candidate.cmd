@echo off
cd /d "%~dp0.."
set STEPS=csim csynth
set NT=7680
set ACT_LUT=2
set HLS_PROJECT=prj_e08
set FEX_INTERNAL_FIXED=1
set FEX_INV_I=8
set DSP_FULL_REG=false
set TARGET_II=2
set CLOCK_UNCERTAINTY_NS=1.0
if not exist results\v1.8_schedule mkdir results\v1.8_schedule
call vitis_hls -f scripts/run_resgru.tcl > results\v1.8_schedule\hls.log 2>&1
exit /b %errorlevel%
