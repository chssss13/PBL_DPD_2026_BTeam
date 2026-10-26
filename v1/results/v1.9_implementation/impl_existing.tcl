# Implement the verified E08 RTL without resetting or resynthesizing HLS.
open_project prj_e08
open_solution sol1
export_design -flow impl -format ip_catalog
exit
