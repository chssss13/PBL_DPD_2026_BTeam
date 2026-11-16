"""Compare real parent and fused entry RTL under transaction stalls/reset."""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CASE = ROOT/'experiments/v3.8'
sys.path.insert(0, str(CASE))
spec = importlib.util.spec_from_file_location('fusion', CASE/'rtl_transform.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
original = (ROOT/'experiments/v3.7/prj_candidate/sol1/syn/verilog/ResGRU_Block_entry_split_proc.v').read_text()
fused, audit = mod.fuse_entry(original)
out = CASE/'entry_protocol_test'
out.mkdir(exist_ok=True)
(out/'parent.v').write_text(original)
(out/'fused.v').write_text(fused)
inputs = re.findall(r'(?m)^input\s+(\[[^\]]+\]\s*)?(\w+);', original)
outputs = re.findall(r'(?m)^output\s+(\[[^\]]+\]\s*)?(\w+);', original)
lines = ['`timescale 1ns/1ps', 'module test;',
    'reg ap_clk=0, ap_rst=1, ap_start=0, ap_continue=0;',
    'always #5 ap_clk=~ap_clk;', 'integer t,j,k,checked=0,stalled=0;',
    "reg [31:0] rng=32'h82718abc;",
    'task step_rng; begin rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5); end endtask']
for width, name in inputs:
    if name not in ['ap_clk','ap_rst','ap_start','ap_continue']:
        if re.search(r'_q[01]$', name):
            lines.append(f'reg {width}p_{name}=0, f_{name}=0;')
        else:
            lines.append(f'reg {width}{name}=0;')
for width, name in outputs:
    lines.append(f'wire {width}p_{name}, f_{name};')
for module, prefix in [('ResGRU_Block_entry_split_proc','p'), ('ResGRU_Entry_Fused','f')]:
    ports = [f'.{name}({prefix+"_"+name if re.search(r"_q[01]$",name) else name})' for _, name in inputs]
    ports += [f'.{name}({prefix}_{name})' for _, name in outputs]
    lines.append(module+' '+prefix+'('+',\n'.join(ports)+');')
for index, (_, name) in enumerate(inputs):
    if re.search(r'_q[01]$', name):
        stem, port = name.rsplit('_q', 1)
        for prefix in ['p','f']:
            lines.append(f'always @(posedge ap_clk) if({prefix}_{stem}_ce{port}) '
                f'{prefix}_{name} <= ((t+1)*7919) ^ ({prefix}_{stem}_address{port}*997) ^ {index*37};')
lines += ['task compare_data; begin']
for _, name in outputs:
    if name.startswith('ap_return_'):
        lines.append(f'if(p_{name} !== f_{name}) $fatal(1,"{name} mismatch t=%0d",t);')
lines += ['checked=checked+1; end endtask', 'initial begin',
    'repeat(3) @(negedge ap_clk); ap_rst=0;',
    'for(t=0;t<250;t=t+1) begin']
for _, name in inputs:
    if name not in ['ap_clk','ap_rst','ap_start','ap_continue'] and not re.search(r'_q[01]$',name):
        lines.append(f'step_rng; {name}=rng;')
lines += ['ap_start=1; @(negedge ap_clk); ap_start=0;',
    'k=0; while(!(p_ap_done && f_ap_done)) begin @(negedge ap_clk); k=k+1; if(k>20) $fatal(1,"entry timeout"); end',
    'step_rng; j=rng%25;',
    'repeat(j) begin compare_data; if(f_ap_ready !== 0) $fatal(1,"ready under backpressure"); stalled=stalled+1; @(negedge ap_clk); end',
    'if(t%17==0) begin ap_rst=1; @(negedge ap_clk); ap_rst=0; end',
    'else begin ap_continue=1; #1; compare_data; if(!f_ap_ready) $fatal(1,"missing ready"); @(negedge ap_clk); ap_continue=0; end',
    '@(negedge ap_clk);', 'end',
    'if(checked<1000 || stalled<1000) $fatal(1,"coverage");',
    '$display("ENTRY_FUSION_PASS transactions=250 checked=%0d stall_cycles=%0d",checked,stalled); $finish;',
    'end', 'endmodule']
(out/'test.sv').write_text('\n'.join(lines))
bin = Path('C:/Xilinx/Vivado/2024.1/bin')
commands = [('xvlog.bat',['--sv','parent.v','fused.v','test.sv']),
            ('xelab.bat',['test','-s','entry_fusion']),
            ('xsim.bat',['entry_fusion','-runall'])]
with (out/'run.log').open('w') as log:
    for exe, args in commands:
        result = subprocess.run([str(bin/exe),*args], cwd=out, stdout=log, stderr=subprocess.STDOUT, timeout=240)
        assert result.returncode == 0, f'{exe} failed: {out}/run.log'
text = (out/'run.log').read_text(errors='replace')
assert 'ENTRY_FUSION_PASS' in text and 'Fatal:' not in text, text[-2500:]
audit.update(pass_protocol=True, transactions=250,
    scope='Real parent/fused entry modules, all 598 outputs, changing transaction inputs and deterministic synchronous address/CE-driven RAM models, random terminal stalls, reset during stalls. Inputs held through completion; not full-network equivalence.')
(CASE/'entry_protocol_test.json').write_text(json.dumps(audit, indent=2))
print(next(line for line in text.splitlines() if 'ENTRY_FUSION_PASS' in line))
