"""Exercise the actual depth-one controller and HLS payload RTL under stalls."""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
case=Path(sys.argv[1]).resolve()
assert case.parent==ROOT/'experiments'
sys.path.insert(0,str(case))
spec=importlib.util.spec_from_file_location('trial_depth',case/'rtl_transform.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
out=case/'protocol_test';out.mkdir(exist_ok=True)
(out/'controller.v').write_text('`timescale 1ns/1ps\n'+module.CONTROL)
payload=ROOT/'experiments/v3.5/prj_candidate/sol1/syn/verilog/ResGRU_fifo_w14_d2_S.v'
shutil.copy2(payload,out/'payload.v')
(out/'test.sv').write_text(r'''
`timescale 1ns/1ps
module test;
reg clk=0, reset=1, wr=0, rd=0;
reg [13:0] din=0;
wire full_n,empty_n,push;
wire [2:0] occupancy;
wire [1:0] addr;
wire [13:0] dout;
reg [13:0] expected;
reg valid=0;
reg take_in,take_out;
integer i, accepted=0, consumed=0, resets=0;
reg [31:0] rng=32'h195a73c1;
always #5 clk=~clk;
fifo_lockstep_control c(clk,reset,wr,rd,full_n,empty_n,occupancy,addr,push);
ResGRU_fifo_w14_d2_S_ShiftReg #(.DATA_WIDTH(14),.ADDR_WIDTH(2),.DEPTH(1)) p(clk,push,addr,din,dout);
initial begin
 repeat(3) @(negedge clk);
 for(i=0;i<20000;i=i+1) begin
  rng=rng ^ (rng<<13);rng=rng ^ (rng>>17);rng=rng ^ (rng<<5);
  reset=(rng[7:0]==0); wr=rng[8]; rd=rng[9]; din=rng[23:10];
  #1;
  if(empty_n !== valid || full_n !== !valid) $fatal(1,"flags differ from abstract queue");
  if(occupancy !== (valid ? 3'd1 : 3'd0)) $fatal(1,"invalid occupancy");
  take_in=wr && full_n;take_out=rd && empty_n;
  if(take_out && !reset) begin
   if(dout !== expected) $fatal(1,"payload order/data mismatch");
   consumed=consumed+1;
  end
  @(posedge clk);
  if(reset) begin valid=0;resets=resets+1;end
  else begin
   if(take_in) begin expected=din;valid=1;accepted=accepted+1;end
   if(take_out) valid=0;
  end
  @(negedge clk);
 end
 if(accepted<1000 || consumed<1000 || resets<10) $fatal(1,"insufficient coverage");
 $display("FIFO_PROTOCOL_PASS cycles=20000 accepted=%0d consumed=%0d resets=%0d",accepted,consumed,resets);
 $finish;
end
endmodule
''')
bin=Path('C:/Xilinx/Vivado/2024.1/bin')
commands=[['xvlog.bat','--sv','controller.v','payload.v','test.sv'],
          ['xelab.bat','test','-s','fifo_protocol'],['xsim.bat','fifo_protocol','-runall']]
with (out/'run.log').open('w') as log:
    for executable,*args in commands:
        result=subprocess.run([str(bin/executable),*args],cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=180)
        assert result.returncode==0, f'Protocol simulation failed: {executable}; see {out}/run.log'
text=(out/'run.log').read_text(errors='replace')
assert 'FIFO_PROTOCOL_PASS' in text and 'Fatal:' not in text
result=dict(pass_protocol=True,cycles=20000,scope='Random payload, read/write stalls, simultaneous requests, reset. Local FIFO protocol only; not full network equivalence.')
(case/'fifo_protocol_test.json').write_text(json.dumps(result,indent=2))
print(next(line for line in text.splitlines() if 'FIFO_PROTOCOL_PASS' in line),flush=True)
