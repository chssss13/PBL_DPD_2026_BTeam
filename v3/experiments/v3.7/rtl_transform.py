"""Depth-one scalar FIFO trial, retaining the v3.6 lockstep grouping.

Capacity changes and can change backpressure. This is not claimed cycle-exact
equivalent to depth two for arbitrary overlapping calls. Full network tests
must show II=2, identical output and no added call stalls before acceptance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import fifo_control_base

MARKER='// FIFO_DEPTH_ONE_V1'
CONTROL="""
module fifo_lockstep_control(input wire clk, reset, wr, rd,
 output reg full_n=1'b1, output reg empty_n=1'b0,
 output reg [2:0] occupancy, output reg [1:0] addr, output wire push);
wire pop = empty_n & rd;
assign push = full_n & wr;
always @(posedge clk) begin
 if (reset) begin addr<=0; occupancy<=0; full_n<=1; empty_n<=0; end
 else begin
  addr<=0;
  if (push & ~pop) begin occupancy<=1; full_n<=0; empty_n<=1; end
  else if (~push & pop) begin occupancy<=0; full_n<=1; empty_n<=0; end
 end
end
endmodule
"""


def transform(folder, report):
    top=folder/'ResGRU.v'
    if MARKER in top.read_text():return
    fifo_control_base.transform(folder,32,report)
    text=top.read_text()
    text,count=re.subn(r'assign (\w+_fifo_cap) = 3\x27d2;',r"assign \1 = 3'd1;",text)
    assert count==598, count
    assert text.count('.DEPTH(2))')==598
    text=text.replace('.DEPTH(2))','.DEPTH(1))')
    text,count=re.subn(r'module fifo_lockstep_control\(.*?\nendmodule',lambda _:CONTROL.strip(),text,flags=re.S)
    assert count==1
    text+='\n'+MARKER+'\n'
    top.write_text(text)
    data=json.loads(report.read_text())
    data.update(depth=1,backpressure_changed=True,
        scope='Payload/control capacity changes from two to one. No arbitrary-cycle equivalence claimed. External handshake obeyed; require measured call interval and full output validation.',
        transformed_sha256=hashlib.sha256(top.read_bytes()).hexdigest())
    report.write_text(json.dumps(data,indent=2))


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('folder',type=Path);ap.add_argument('--report',type=Path,required=True)
    args=ap.parse_args();transform(args.folder,args.report)
