# LW-ResGRU 鍮뚮뱶 ?ㅽ겕由쏀듃 (Vitis HLS 2024.1)
#
# ?대뜑 援ъ“ (???뚯씪? scripts/ ?꾨옒):
#   <root>/src/      multi_gru.cpp 諛??ㅻ뜑
#   <root>/tb/       tb_resgru.cpp
#   <root>/golden/   export_golden.py 異쒕젰
#   <root>/results/  hls_out.txt媛 ??λ맖
#
# ?ㅽ뻾:  cd <root> && vitis_hls -f scripts/run_resgru.tcl
#   STEPS ?섍꼍蹂?섎줈 ?④퀎 ?좏깮 (湲곕낯 csim):  STEPS="csim csynth cosim impl" vitis_hls -f ...
#   NT ?섍꼍蹂?섎줈 ?섑뵆 ???좏깮 (湲곕낯 7680, cosim? 640 ?뺣룄 沅뚯옣)
#

set ROOT  [file normalize [file join [file dirname [info script]] ..]]
set STEPS [expr {[info exists ::env(STEPS)] ? $::env(STEPS) : "csim"}]
set NT    [expr {[info exists ::env(NT)] ? $::env(NT) : 7680}]
set CFLAGS "-I$ROOT/src -DRESET_ARG"
foreach DEFINE {FEX_INTERNAL_FIXED FEX_INV_I ACT_LUT DIRECT_LUT_SHIFT V2_ROM V2_ACT_REG V2_TREE V2_GATE} {
    if {[info exists ::env($DEFINE)]} {
        if {![string is integer -strict $::env($DEFINE)]} { error "$DEFINE must be an integer" }
        append CFLAGS " -D$DEFINE=$::env($DEFINE)"
    }
}

file mkdir $ROOT/results
set PROJECT [expr {[info exists ::env(HLS_PROJECT)] ? $::env(HLS_PROJECT) : "prj_resgru"}]
open_project -reset $PROJECT
set_top ResGRU
add_files $ROOT/src/multi_gru.cpp -cflags $CFLAGS
add_files -tb $ROOT/tb/tb_resgru.cpp -cflags $CFLAGS

open_solution -reset sol1
set_part {xczu7ev-ffvc1156-2-e}
set PERIOD [expr {[info exists ::env(HLS_CLOCK_NS)] ? $::env(HLS_CLOCK_NS) : 15}]
create_clock -period $PERIOD -name default   ;# ?쇰Ц 議곌굔 66 MHz
if {[info exists ::env(CLOCK_UNCERTAINTY_NS)]} {
    set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_NS)
}
if {[info exists ::env(DSP_FULL_REG)]} {
    config_schedule -enable_dsp_full_reg=$::env(DSP_FULL_REG)
}
if {[info exists ::env(TARGET_II)]} {
    set_directive_pipeline -II $::env(TARGET_II) "ResGRU/LOOP_T"
}

set OUTFILE [expr {[info exists ::env(HLS_OUTPUT)] ? $::env(HLS_OUTPUT) : "$ROOT/results/hls_out.txt"}]
set OUTFILE [file normalize $OUTFILE]
set ARGV "$ROOT/../v1/golden $NT $OUTFILE"
if {[lsearch $STEPS csim]   >= 0} { csim_design -argv $ARGV }
if {[lsearch $STEPS csynth] >= 0} { csynth_design }
if {[lsearch $STEPS cosim]  >= 0} { cosim_design -argv $ARGV }
# impl: Vivado out-of-context ?⑹꽦쨌諛곗튂쨌諛곗꽑 (HLS??create_clock ?쒖빟 ?곸슜). 由ы룷?몃뒗 sol1/impl/report/
if {[lsearch $STEPS impl]   >= 0} { export_design -flow impl -format ip_catalog }
exit

