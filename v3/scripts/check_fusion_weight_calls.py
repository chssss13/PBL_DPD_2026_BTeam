"""Additional C/RTL regression in an isolated copy of the synthesis database."""
import hashlib
import json
from pathlib import Path
import subprocess
import shutil

ROOT = Path(__file__).resolve().parents[1]
CASE = ROOT/'experiments/v3.8'
OUT = ROOT/'results/v3.8/weight_call_regression'
state = json.loads((ROOT/'results/v3.8/state.json').read_text())
assert all(stage in state['completed'] for stage in ['csim','csynth','cosim'])
assert (CASE/'implementation_rtl_audit.json').exists(), 'Wait for export installation before copying immutable synthesis artifacts'
PROJECT = CASE/'prj_weight_regression'
original_project = CASE/'prj_candidate'
solution = PROJECT/'sol1'
if not PROJECT.exists():
    PROJECT.mkdir()
    shutil.copy2(original_project/'hls.app', PROJECT/'hls.app')
    (PROJECT/'hls.app').write_text((PROJECT/'hls.app').read_text().replace('name="prj_candidate"','name="prj_weight_regression"'))
    solution.mkdir()
    for folder in ['.autopilot','syn']:
        shutil.copytree(original_project/'sol1'/folder,solution/folder)
    for file in (original_project/'sol1').iterdir():
        if file.is_file() and file.suffix in ['.aps','.directive','.json']:
            shutil.copy2(file, solution/file.name)
            if file.suffix == '.aps':
                target = solution/file.name
                target.write_text(target.read_text().replace('string="prj_candidate"','string="prj_weight_regression"'))
else:
    previous = (OUT/'run.log').read_text(errors='replace')
    assert 'Unknown option' in previous or 'undefined symbol: ResGRU' in previous, 'Only known pre-simulation setup errors may resume automatically'
    index = 1
    while (OUT/f'setup_error_{index}.log').exists():
        index += 1
    shutil.copy2(OUT/'run.log',OUT/f'setup_error_{index}.log')
OUT.mkdir(exist_ok=True)
tb = (CASE/'tb/tb_resgru.cpp').read_text(encoding='utf-8')
mutation = '''
        // Every call changes all weight/bias families. Values remain in their
        // declared fixed-point domains; transport equivalence, not PA quality.
        for(int i=0;i<H_SIZE;i++) {
            for(int j=0;j<6;j++) W_inj[i][j].range(13,0)=ap_uint<14>((blk+1)*251+i*61+j*19);
            b_inj[i].range(14,0)=ap_uint<15>((blk+1)*127+i*43);
        }
        prelu.range(13,0)=ap_uint<14>((blk+1)*997);
        for(int l=0;l<NUM_LAYERS;l++) {
            gating[l].range(13,0)=ap_uint<14>((blk+1)*37+l*97);
            for(int i=0;i<H_SIZE;i++) {
                b_ir[l][i].range(14,0)=ap_uint<15>((blk+1)*503+l*31+i*17);
                b_hr[l][i].range(14,0)=ap_uint<15>((blk+1)*701+l*43+i*29);
                b_iz[l][i].range(14,0)=ap_uint<15>((blk+1)*809+l*59+i*41);
                b_hz[l][i].range(14,0)=ap_uint<15>((blk+1)*907+l*71+i*53);
                b_in[l][i].range(14,0)=ap_uint<15>((blk+1)*1013+l*83+i*67);
                b_hn[l][i].range(14,0)=ap_uint<15>((blk+1)*1103+l*97+i*79);
                for(int j=0;j<H_SIZE;j++) {
                    W_ir[l][i][j].range(13,0)=ap_uint<14>((blk+1)*1237+l*101+i*23+j*11);
                    W_hr[l][i][j].range(13,0)=ap_uint<14>((blk+1)*1423+l*103+i*37+j*13);
                    W_iz[l][i][j].range(13,0)=ap_uint<14>((blk+1)*1613+l*107+i*47+j*17);
                    W_hz[l][i][j].range(13,0)=ap_uint<14>((blk+1)*1811+l*109+i*59+j*19);
                    W_in[l][i][j].range(13,0)=ap_uint<14>((blk+1)*2017+l*113+i*71+j*23);
                    W_hn[l][i][j].range(13,0)=ap_uint<14>((blk+1)*2221+l*127+i*83+j*29);
                }
            }
        }
        for(int i=0;i<2;i++) {
            b_out[i].range(14,0)=ap_uint<15>((blk+1)*233+i*173);
            for(int j=0;j<H_SIZE;j++) W_out[i][j].range(13,0)=ap_uint<14>((blk+1)*331+i*181+j*31);
        }
'''
assert tb.count('        ResGRU(IQ, OUT,') == 1
tb = tb.replace('        ResGRU(IQ, OUT,', mutation+'        ResGRU(IQ, OUT,')
tb = tb.replace('(blk * TIME_STEP) % SEG == 0', '(blk % 7 == 0 || blk % 11 == 0)')
extra = OUT/'tb_weight_calls.cpp'
extra.write_text(tb, encoding='utf-8')
original = CASE/'tb/tb_resgru.cpp'
script = f'''
open_project {{{PROJECT.as_posix()}}}
open_solution sol1
set_top ResGRU
remove_files {{{original.as_posix()}}}
add_files {{{CASE.as_posix()}/src/multi_gru.cpp}} -cflags {{-I{CASE.as_posix()}/src -DRESET_ARG}}
add_files -tb {{{extra.as_posix()}}} -cflags {{-I{CASE.as_posix()}/src -DRESET_ARG}}
set rc [catch {{
    csim_design -argv {{{ROOT.as_posix()}/golden 1536 {OUT.as_posix()}/c_out.txt 2560}}
    cosim_design -rtl verilog -tool xsim -argv {{{ROOT.as_posix()}/golden 1536 {OUT.as_posix()}/rtl_out.txt 2560}}
}} message options]
remove_files {{{extra.as_posix()}}}
add_files -tb {{{original.as_posix()}}} -cflags {{-I{CASE.as_posix()}/src -DRESET_ARG}}
close_project
if {{$rc}} {{ puts $message; exit 1 }}
exit
'''
tcl = OUT/'run.tcl'
tcl.write_text(script)
with (OUT/'run.log').open('w') as log:
    result = subprocess.run(['C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat','-f',str(tcl)], cwd=CASE, stdout=log, stderr=subprocess.STDOUT)
assert result.returncode == 0, 'Supplementary regression failed; inspect weight_call_regression/run.log'
import numpy as np
c, rtl = [np.loadtxt(OUT/name) for name in ['c_out.txt','rtl_out.txt']]
assert c.shape == rtl.shape == (1536,2)
mismatches = int(np.count_nonzero(np.rint(c*4096) != np.rint(rtl*4096)))
assert mismatches == 0, mismatches
report = PROJECT/'sol1/sim/report/ResGRU_cosim.rpt'
(OUT/'ResGRU_cosim.rpt').write_bytes(report.read_bytes())
syn = PROJECT/'sol1/syn/verilog/ResGRU.v'
sim = PROJECT/'sol1/sim/verilog/ResGRU.v'
assert syn.read_bytes() == sim.read_bytes()
installed = json.loads((CASE/'implementation_rtl_audit.json').read_text())
assert hashlib.sha256(sim.read_bytes()).hexdigest() == installed['source_sha256'], 'Regression RTL differs from primary implementation RTL'
summary = dict(pass_regression=True,samples=1536,calls=24,q12_mismatches=mismatches,
    changed_parameters='All weight/bias families on each call',
    reset_calls=[b for b in range(24) if b%7==0 or b%11==0],
    rtl_sha256=hashlib.sha256(sim.read_bytes()).hexdigest(),
    scope='Fresh C versus existing transformed RTL, changed runtime weights and software hidden-state reset pattern; no PA quality claim, no forced system reset or arbitrary external backpressure.')
(OUT/'summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary), flush=True)
