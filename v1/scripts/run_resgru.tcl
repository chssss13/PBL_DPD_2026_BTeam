# LW-ResGRU 빌드 스크립트 (Vitis HLS 2024.1)
#
# 폴더 구조 (이 파일은 scripts/ 아래):
#   <root>/src/      multi_gru.cpp 및 헤더
#   <root>/tb/       tb_resgru.cpp
#   <root>/golden/   export_golden.py 출력
#   <root>/results/  hls_out.txt가 저장됨
#
# 실행:  cd <root> && vitis_hls -f scripts/run_resgru.tcl
#   STEPS 환경변수로 단계 선택 (기본 csim):  STEPS="csim csynth cosim impl" vitis_hls -f ...
#   NT 환경변수로 샘플 수 선택 (기본 7680, cosim은 640 정도 권장)
#

set ROOT  [file normalize [file join [file dirname [info script]] ..]]
set STEPS [expr {[info exists ::env(STEPS)] ? $::env(STEPS) : "csim"}]
set NT    [expr {[info exists ::env(NT)] ? $::env(NT) : 7680}]
set CFLAGS "-I$ROOT/src -DRESET_ARG"
foreach DEFINE {FEX_INTERNAL_FIXED FEX_INV_I} {
    if {[info exists ::env($DEFINE)]} {
        if {![string is integer -strict $::env($DEFINE)]} { error "$DEFINE must be an integer" }
        append CFLAGS " -D$DEFINE=$::env($DEFINE)"
    }
}

file mkdir $ROOT/results
open_project -reset prj_resgru
set_top ResGRU
add_files $ROOT/src/multi_gru.cpp -cflags $CFLAGS
add_files -tb $ROOT/tb/tb_resgru.cpp -cflags $CFLAGS

open_solution -reset sol1
set_part {xczu7ev-ffvc1156-2-e}
create_clock -period 15 -name default   ;# 논문 조건 66 MHz

set ARGV "$ROOT/golden $NT $ROOT/results/hls_out.txt"
if {[lsearch $STEPS csim]   >= 0} { csim_design -argv $ARGV }
if {[lsearch $STEPS csynth] >= 0} { csynth_design }
if {[lsearch $STEPS cosim]  >= 0} { cosim_design -argv $ARGV }
# impl: Vivado out-of-context 합성·배치·배선 (HLS의 create_clock 제약 적용). 리포트는 sol1/impl/report/
if {[lsearch $STEPS impl]   >= 0} { export_design -flow impl -format ip_catalog }
exit
