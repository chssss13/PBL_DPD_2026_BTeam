set ROOT [file normalize [file dirname [info script]]]
cd $ROOT
if {[file exists "$ROOT/prj/sol1/impl/report"] || [file exists "$ROOT/prj/sol1/impl/verilog/project.runs"]} {error "Refusing to overwrite implementation"}
open_project prj
open_solution sol1
config_export -vivado_clock 15
export_design -format ip_catalog
puts [exec C:/PBL/venv/Scripts/python.exe $ROOT/prepare_impl.py]
cd $ROOT/prj/sol1/impl/verilog
exec C:/Xilinx/Vivado/2024.1/bin/vivado.bat -mode batch -source run_vivado.tcl >@ stdout 2>@ stderr
exit
