@echo off
call C:\Xilinx\Vitis_HLS\2024.1\settings64.bat
if errorlevel 1 exit /b 1
set "RESET_ARG=1"
set "NT=7680"
call vitis_hls -f synth_existing.tcl > csynth.log 2>&1
exit /b %errorlevel%
