# Candidate 01: same device/clock/uncertainty/II constraints as the previous run.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
cd $ROOT
set ::env(STEPS) csynth
set ::env(NT) 7680
set ::env(ACT_LUT) 3
set ::env(DIRECT_LUT_SHIFT) 4
set ::env(FEX_INTERNAL_FIXED) 1
set ::env(FEX_INV_I) 8
set ::env(DSP_FULL_REG) false
set ::env(TARGET_II) 2
set ::env(CLOCK_UNCERTAINTY_NS) 1.0
set ::env(HLS_PROJECT) prj_timing_candidate01_synth
set ::env(HLS_OUTPUT) results/timing_candidate01/hls_out.txt
if {[file exists $::env(HLS_PROJECT)]} {
    error "Project already exists; preserve it and choose a new project name."
}
source [file join $ROOT scripts run_resgru.tcl]
