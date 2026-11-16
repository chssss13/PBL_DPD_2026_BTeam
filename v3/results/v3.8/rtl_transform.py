"""Guarded experiment: keep entry terminal state live until FIFO transfer."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import depth_one_base

MARKER = '// FIFO_ENTRY_FUSION_V1'


def fuse_entry(text):
    original = text
    # Each return chooses its live terminal-state computation or a holding reg.
    mux = re.compile(r'always @ \(\*\) begin\s+if \(\(1\'b1 == ap_CS_fsm_state4\)\) begin\s+'
        r'(ap_return_\d+) = ([^;]+);\s+end else begin\s+\1 = (ap_return_\d+_preg);\s+end\s+end')
    matches = list(mux.finditer(text))
    assert len(matches) == 598, len(matches)
    regs = {m[3] for m in matches}
    # Source calculations may depend on input ports or internal earlier-state regs,
    # but never on one of the output holding registers being removed.
    for m in matches:
        assert m[3] == m[1] + '_preg'
        assert not any(re.search(r'\b'+re.escape(r)+r'\b', m[2]) for r in regs)
    text = mux.sub(lambda m: 'always @ (*) begin\n    '+m[1]+' = '+m[2]+';\nend', text)
    blocks = re.compile(r'always @ \(posedge ap_clk\) begin\n.*?\nend', re.S)
    removed = []
    def drop(block):
        names = set(re.findall(r'\b(ap_return_\d+_preg)\b', block[0]))
        if not names:
            return block[0]
        if "ap_CS_fsm_state4" not in block[0]:
            stripped = re.sub(r'\s*ap_return_\d+_preg(?:\[[^\]]+\])? <= \d+\x27b[01]+;', '', block[0])
            assert re.sub(r'\s+', '', stripped) == 'always@(posedgeap_clk)beginend'
            return ''
        assert len(names) == 1 and names <= regs
        assert "if ((1'b1 == ap_CS_fsm_state4)) begin" in block[0]
        removed.extend(names)
        return ''
    text = blocks.sub(drop, text)
    assert set(removed) == regs and len(removed) == 598
    text, declarations = re.subn(r'(?m)^reg\s+(?:\[[^\]]+\]\s+)?ap_return_\d+_preg;\n', '', text)
    assert declarations == 598
    text = re.sub(r'(?m)^#0 ap_return_\d+_preg = [^;]+;\n', '', text)
    # HLS assigns constant low bits to some holding regs in a separate block.
    text = re.sub(r'(?m)^\s*ap_return_\d+_preg(?:\[[^\]]+\])? <= [^;]+;\n', '', text)
    assert not re.search(r'\bap_return_\d+_preg\b', text)
    old = 'ap_ST_fsm_state4 : begin\n            ap_NS_fsm = ap_ST_fsm_state1;\n        end'
    assert text.count(old) == 1
    text = text.replace(old, "ap_ST_fsm_state4 : begin\n            if (ap_continue) ap_NS_fsm = ap_ST_fsm_state1;\n            else ap_NS_fsm = ap_ST_fsm_state4;\n        end")
    ready = "if ((1'b1 == ap_CS_fsm_state4)) begin\n        ap_ready = 1'b1;"
    assert text.count(ready) == 1
    text = text.replace(ready, "if ((1'b1 == ap_CS_fsm_state4)) begin\n        ap_ready = ap_continue;")
    text = text.replace('module ResGRU_Block_entry_split_proc (', 'module ResGRU_Entry_Fused (', 1)
    return text, dict(removed_output_registers=598,
        original_entry_sha256=hashlib.sha256(original.encode()).hexdigest(),
        fused_entry_sha256=hashlib.sha256(text.encode()).hexdigest())


def transform(folder, report):
    top = folder/'ResGRU.v'
    if MARKER in top.read_text():
        return
    depth_one_base.transform(folder, report)
    entry, audit = fuse_entry((folder/'ResGRU_Block_entry_split_proc.v').read_text())
    text = top.read_text()
    text, count = re.subn(r'\bResGRU_Block_entry_split_proc\s+Block_entry_split_proc_U0\s*\(',
        'ResGRU_Entry_Fused Block_entry_split_proc_U0 (', text)
    assert count == 1
    # Embed changed submodule in top so existing export installation carries it.
    text += '\n'+MARKER+'\n'+entry
    top.write_text(text)
    data = json.loads(report.read_text())
    data.update(entry_fusion=audit, transformed_sha256=hashlib.sha256(top.read_bytes()).hexdigest())
    report.write_text(json.dumps(data, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('folder', type=Path)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    transform(args.folder, args.report)
