"""Guarded RTL transformation of lockstep scalar FIFO controllers.

Payload shift registers are preserved. Equivalence follows by induction from
identical initialization, reset, read controls and producer synchronization.
This is a local structural proof, not a formal proof of the complete network.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

MARKER = '// FIFO_CONTROL_SHARE_V1'
PATTERN = re.compile(r'(?m)^(ResGRU_fifo_w(\d+)_d2_S)\s+(\w+)\s*\((.*?)\n\);', re.S)


def audit(text, folder):
    rows = []
    for match in PATTERN.finditer(text):
        module, width, inst, body = match.groups()
        ports = dict(re.findall(r'\.(\w+)\(([^\n]*)\)', body))
        prefix = inst.removesuffix('_U')
        assert ports['if_write'] == 'ap_channel_done_' + prefix, inst
        assert ports['if_read'] == 'Loop_LOOP_T_proc_U0_ap_ready', inst
        assert ports['if_write_ce'] == ports['if_read_ce'] == "1'b1", inst
        assert ports['clk'] == 'ap_clk' and ports['reset'] == 'ap_rst'
        for port, suffix in [('if_full_n', '_full_n'), ('if_empty_n', '_empty_n'),
                             ('if_num_data_valid', '_num_data_valid'), ('if_fifo_cap', '_fifo_cap')]:
            assert ports[port] == prefix + suffix, (inst, port)
        flag = 'ap_sync_reg_channel_write_' + prefix
        assert re.search(r'#0\s+' + re.escape(flag) + r"\s*=\s*1'b0;", text), inst
        blocks = [b for b in re.findall(r'always @ \(posedge ap_clk\) begin\n.*?\nend', text, re.S)
                  if re.search(re.escape(flag) + r'\s*<=', b)]
        assert len(blocks) == 1, inst
        normalized = re.sub(r'\s+', '', blocks[0].replace(prefix, 'CHANNEL'))
        expected = """always@(posedgeap_clk)beginif(ap_rst==1'b1)begin
        ap_sync_reg_channel_write_CHANNEL<=1'b0;endelsebegin
        if(((Block_entry_split_proc_U0_ap_done&Block_entry_split_proc_U0_ap_continue)==1'b1))begin
        ap_sync_reg_channel_write_CHANNEL<=1'b0;endelsebegin
        ap_sync_reg_channel_write_CHANNEL<=ap_sync_channel_write_CHANNEL;endendend"""
        assert normalized == re.sub(r'\s+', '', expected), inst
        for signal, terms in [
            ('ap_channel_done_' + prefix, [flag + "^1'b1", 'Block_entry_split_proc_U0_ap_done']),
            ('ap_sync_channel_write_' + prefix,
             ['ap_channel_done_' + prefix, prefix + '_full_n', flag])]:
            assign = re.search(r'assign\s+' + re.escape(signal) + r'\s*=\s*(.*?);', text)[1]
            # Check expression structure independently of operand order.
            compact = re.sub(r'[\s()]', '', assign)
            if signal.startswith('ap_channel_done_'):
                assert compact == terms[0] + '&' + terms[1], (inst, compact)
            else:
                assert compact in [terms[0]+'&'+terms[1]+'|'+terms[2], terms[1]+'&'+terms[0]+'|'+terms[2]], inst
        code = (folder/(module+'.v')).read_text()
        assert 'DEPTH        = 2' in code and "empty_n = 1'b0" in code and "full_n = 1'b1" in code
        # All controller RTL must be identical apart from width/module names.
        normalized_code = code[code.index('module '):code.index('endmodule')]
        normalized_code = normalized_code.replace(module, 'FIFO')
        normalized_code = re.sub(r'DATA_WIDTH\s*=\s*\d+', 'DATA_WIDTH=WIDTH', normalized_code)
        if rows:
            assert normalized_code == rows[0]['controller'], inst
        rows.append(dict(match=match, module=module, width=int(width), instance=inst, ports=ports,
                         controller=normalized_code))
    assert len(rows) == 598, f'Expected 598 depth-2 scalar FIFOs, got {len(rows)}'
    return rows


def transform(folder, group_size, report):
    top = folder/'ResGRU.v'
    text = top.read_text()
    if MARKER in text:
        # HLS deadlock monitoring addresses the original FIFO instance paths.
        # Preserve these four observation signals without changing the monitor.
        if '// FIFO_MONITOR_ALIASES' not in text:
            data = json.loads(report.read_text())
            aliases = ['// FIFO_MONITOR_ALIASES', 'generate']
            for row in data['channels']:
                inst = row['instance']
                prefix = inst.removesuffix('_U')
                aliases += [f'if (1) begin : {inst}',
                            f'wire if_empty_n = {prefix}_empty_n;',
                            f'wire if_full_n = {prefix}_full_n;',
                            f'wire if_read = Loop_LOOP_T_proc_U0_ap_ready;',
                            f'wire if_write = ap_channel_done_{prefix};', 'end']
            aliases += ['endgenerate']
            assert text.count('endmodule //ResGRU') == 1
            text = text.replace('endmodule //ResGRU', '\n'.join(aliases)+'\nendmodule //ResGRU')
            top.write_text(text)
            data['transformed_sha256'] = hashlib.sha256(top.read_bytes()).hexdigest()
            data['monitor_observation_paths_preserved'] = True
            report.write_text(json.dumps(data, indent=2))
        return
    rows = audit(text, folder)
    replacements = []
    for start in range(0, len(rows), group_size):
        group = rows[start:start+group_size]
        leader = group[0]
        p = leader['ports']
        tag = f'fifo_shared_{start//group_size}'
        lines = [f'wire [1:0] {tag}_addr;', f'wire {tag}_push;']
        # Explicit controller uses exactly the original equations and initial state.
        lines += [f'fifo_lockstep_control {tag}_control(',
                  f".clk(ap_clk), .reset(ap_rst), .wr({p['if_write']}), .rd({p['if_read']}),",
                  f".full_n({p['if_full_n']}), .empty_n({p['if_empty_n']}),",
                  f".occupancy({p['if_num_data_valid']}), .addr({tag}_addr), .push({tag}_push));"]
        for row in group:
            q = row['ports']
            lines += [f"assign {q['if_fifo_cap']} = 3'd2;"]
            if row is not leader:
                lines += [f"assign {q[key]} = {p[key]};" for key in ['if_full_n', 'if_empty_n', 'if_num_data_valid']]
            lines += [f"{row['module']}_ShiftReg #(.DATA_WIDTH({row['width']}), .ADDR_WIDTH(2), .DEPTH(2)) {row['instance']}_payload (",
                      f".clk(ap_clk), .we({tag}_push), .addr({tag}_addr), .din({q['if_din']}), .dout({q['if_dout']}));"]
        replacements.append((leader['match'].start(), leader['match'].end(), '\n'.join(lines)))
        replacements += [(r['match'].start(), r['match'].end(), '') for r in group[1:]]
    for start, end, replacement in sorted(replacements, reverse=True):
        text = text[:start]+replacement+text[end:]
    text += '\n'+MARKER+'\n'+CONTROL
    top.write_text(text)
    data = dict(fifo_count=598, group_size=group_size, shared_controllers=(598+group_size-1)//group_size,
                payload_bits_per_slot=sum(r['width'] for r in rows),
                proof='Identical initial empty/full, synchronous reset, read controls, producer done/continue and per-channel synchronization transitions. Equal controller state is an inductive invariant; payload storage and latency remain unchanged.',
                transformed_sha256=hashlib.sha256(top.read_bytes()).hexdigest(),
                channels=[dict(instance=r['instance'], width=r['width']) for r in rows])
    report.write_text(json.dumps(data, indent=2))
    print(json.dumps({k:v for k,v in data.items() if k!='channels'}), flush=True)
    transform(folder, group_size, report)


CONTROL = """
module fifo_lockstep_control(input wire clk, reset, wr, rd,
 output reg full_n=1'b1, output reg empty_n=1'b0,
 output reg [2:0] occupancy, output reg [1:0] addr, output wire push);
wire pop = empty_n & rd;
assign push = full_n & wr;
always @(posedge clk) begin
 if (reset) begin addr<=0; occupancy<=0; full_n<=1; empty_n<=0; end
 else begin
  if (push & ~pop & empty_n) addr<=addr+1'b1;
  else if (~push & pop & (occupancy!=1)) addr<=addr-1'b1;
  if (push & ~pop) occupancy<=occupancy+1'b1;
  else if (~push & pop) occupancy<=occupancy-1'b1;
  if ((push & ~pop) & (occupancy==1)) full_n<=0;
  else if (~push & pop) full_n<=1;
  if (push & ~pop) empty_n<=1;
  else if ((~push & pop) & (occupancy==1)) empty_n<=0;
 end
end
endmodule
"""


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('folder', type=Path)
    ap.add_argument('--group-size', type=int, default=32)
    ap.add_argument('--report', type=Path, required=True)
    ap.add_argument('--audit-only', action='store_true')
    args = ap.parse_args()
    if args.audit_only:
        rows = audit((args.folder/'ResGRU.v').read_text(), args.folder)
        args.report.write_text(json.dumps(dict(channels=len(rows), bits=sum(r['width'] for r in rows), structural_conditions_pass=True), indent=2))
        print(args.report.read_text())
    else:
        transform(args.folder, args.group_size, args.report)
