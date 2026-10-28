@echo off
call C:\Xilinx\Vitis_HLS\2024.1\settings64.bat
if errorlevel 1 exit /b 1
set "RESET_ARG=1"
set "NT=7680"
set "STEPS=csim"
call vitis_hls -f scripts/run_resgru.tcl > csim.log 2>&1
exit /b %errorlevel%
