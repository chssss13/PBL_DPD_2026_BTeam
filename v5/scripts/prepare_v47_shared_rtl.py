"""Generate resource-only shared-gate candidates directly from v4.7 RTL."""
import argparse
import re
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "v4/result/v4.7/final_rtl"
CONSUMER = "ResGRU_Loop_LOOP_T_proc.v"


def share_gates(source, scope):
    # HLS labels the reset product by its original source line (282).
    reset_pattern = re.compile(
        r"(\.din1\()(\w+sigmoid\w+_ap_return)(\),\s*"
        r"\.dout\(mul_ln282(?:_(\d+))?_fu_\d+_p2\))"
    )
    update_pattern = re.compile(
        r"assign z_gate(?:_(\d+))?_fu_\d+_p1 = (\w+sigmoid\w+_ap_return)\[11:0\];"
    )
    updates = {int(index or 0): wire for index, wire in update_pattern.findall(source)}
    resets = {int(m[4] or 0): m[2] for m in reset_pattern.finditer(source)}
    if set(updates) != set(range(15)) or set(resets) != set(updates):
        raise ValueError("Unexpected v4.7 gate wiring")
    if any(resets[i] != resets[i + 5] or updates[i] != updates[i + 5] for i in range(5)):
        raise ValueError("Expected layers 1 and 2 to share sigmoid instances")
    selected = range(5, 10) if scope == "layer2" else range(15)

    def replace_product(match):
        index = int(match[4] or 0)
        if index not in selected or index >= 10:
            return match[0]
        return match[1] + updates[index] + match[3]

    result = reset_pattern.sub(replace_product, source)
    if scope == "layer2":
        # The retained reset sigmoid serves layer 1 in iter2/stage1.
        # Remove its now-unused layer 2 operand in iter4/stage0.
        for index in selected:
            sink = resets[index].removesuffix("_ap_return") + "_data"
            branch = re.compile(
                r"(if \([^\n]*ap_enable_reg_pp0_iter4[^\n]*ap_CS_fsm_pp0_stage0[^\n]*\) begin\s*"
                + re.escape(sink) + r" = )select_ln280_\d+_reg_\d+;"
            )
            result, count = branch.subn(r"\g<1>15'd0;", result)
            if count != 1:
                raise ValueError(f"Missing layer 2 reset operand for {sink}")
    if scope == "all":
        # Layer 3 uses one sigmoid in adjacent cycles for reset and update.
        # Evaluate z in the former reset cycle and retain it for the update.
        for index in range(10, 15):
            wire = updates[index]
            if wire != resets[index]:
                raise ValueError("Expected one time-shared layer 3 sigmoid")
            sink = wire.removesuffix("_ap_return") + "_data"
            later = re.compile(
                r"(if \([^\n]*ap_enable_reg_pp0_iter6[^\n]*ap_CS_fsm_pp0_stage0[^\n]*\)"
                r" begin\s*" + re.escape(sink) + r" = )(select_ln287_\d+_reg_\d+);"
            )
            earlier = re.compile(
                r"(if (\([^\n]*ap_enable_reg_pp0_iter5[^\n]*ap_CS_fsm_pp0_stage1[^\n]*\))"
                r" begin\s*" + re.escape(sink) + r" = )select_ln280_\d+_reg_\d+;"
            )
            update_input = later.search(result)
            reset_cycle = earlier.search(result)
            if update_input is None or reset_cycle is None:
                raise ValueError(f"Unexpected layer 3 sigmoid schedule: {sink}")
            result = later.sub(r"\g<1>15'd0;", result, count=1)
            result = earlier.sub(lambda m: m[1] + update_input[2] + ";", result, count=1)
            register = f"shared_z_layer3_{index - 10}"
            assignment = f" = {wire}[11:0];"
            if result.count(assignment) != 1:
                raise ValueError(f"Unexpected layer 3 update fanout: {wire}")
            result = result.replace(assignment, f" = {register};")
            result = result.replace(
                "endmodule",
                f"reg [11:0] {register};\n"
                f"always @(posedge ap_clk) begin\n"
                f"    if ({reset_cycle[2]}) {register} <= {wire}[11:0];\n"
                f"end\n\nendmodule",
                1,
            )
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scope", choices=["baseline", "layer2", "all"])
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    source = (BASELINE / CONSUMER).read_bytes()
    if args.scope != "baseline":
        source = share_gates(source.decode("ascii"), args.scope).encode("ascii")
    shutil.copytree(BASELINE, args.output)
    (args.output / CONSUMER).write_bytes(source)


if __name__ == "__main__":
    main()
