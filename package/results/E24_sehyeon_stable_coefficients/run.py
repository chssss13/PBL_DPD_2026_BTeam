"""One experiment, sequential tools, final reports only; no status tracker."""
from pathlib import Path
from datetime import datetime
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import traceback
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
WORK = REPO / "runs/e24"
HLS = "C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat"
VIVADO = "C:/Xilinx/Vivado/2024.1/bin/vivado.bat"
STAGES = ["synthesis", "cosim", "export", "implementation", "summary"]
completed = []
started_at = datetime.now().astimezone().isoformat()


def verify_source():
    expected = json.loads((ROOT / "source_hashes.json").read_text())
    for name, digest in expected.items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError(f"Candidate source changed: {name}")


def execute(stage, executable, script):
    log = ROOT / "logs" / f"{stage}.log"
    if log.exists():
        log = log.with_name(log.stem + "_" + datetime.now().strftime("%Y%m%d_%H%M%S") + ".log")
    command = ["cmd.exe", "/d", "/c", executable]
    if executable == HLS:
        command += ["-f", str(ROOT / "scripts" / script)]
    else:
        command += ["-mode", "batch", "-source", str(ROOT / "scripts" / script),
                    "-log", str(ROOT / "logs/vivado_implementation.log"),
                    "-journal", str(ROOT / "logs/vivado_implementation.jou")]
    with log.open("wb") as output:
        result = subprocess.run(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                stdout=output, stderr=subprocess.STDOUT,
                                creationflags=subprocess.CREATE_NO_WINDOW)
    completed.append({"stage": stage, "returncode": result.returncode, "log": str(log)})
    if result.returncode:
        raise RuntimeError(f"{stage} failed with code {result.returncode}: {log}")


def require_ii():
    xml = ET.parse(WORK / "prj/sol1/syn/report/Loop_LOOP_T_proc_csynth.xml").getroot()
    ii = int(xml.findtext(".//SummaryOfLoopLatency/LOOP_T/PipelineII"))
    if ii != 2:
        raise RuntimeError(f"LOOP_T II={ii}; required II=2. No P&R on a failed schedule.")
    return ii


def stage_metrics(name):
    folder = ROOT / "reports" / name
    text = (folder / "timing_summary.rpt").read_text()
    lines = text.splitlines()
    header = next(i for i, line in enumerate(lines) if "WNS(ns)" in line)
    row = lines[header + 2].split()
    if len(row) != 12:
        raise RuntimeError(f"Unexpected timing report row: {row}")
    util = (folder / "utilization.rpt").read_text()

    def used(label):
        match = re.search(r"^\|\s*" + re.escape(label) + r"\s*\|\s*([\d,.]+)\s*\|", util, re.M)
        if not match:
            raise RuntimeError(f"Missing utilization row: {label}")
        value = float(match[1].replace(",", ""))
        return int(value) if value.is_integer() else value

    route = (folder / "route_status.rpt").read_text()

    def nets(label):
        match = re.search(re.escape(label) + r"[^:]*:\s*(\d+)", route)
        if not match:
            raise RuntimeError(f"Missing route status: {label}")
        return int(match[1])

    failure = {"setup": int(row[2]), "hold": int(row[6]), "pulse_width": int(row[10])}
    wns, whs, pw = float(row[0]), float(row[4]), float(row[8])
    return {
        "WNS_ns": wns, "TNS_ns": float(row[1]), "WHS_ns": whs,
        "THS_ns": float(row[5]), "WPWS_ns": pw, "failing_endpoints": failure,
        "comparison_period_ns": round(15 - wns, 3),
        "timing_pass": min(wns, whs, pw) >= 0 and not any(failure.values()),
        "resources": {"LUT": used("CLB LUTs"), "FF": used("CLB Registers"),
                      "DSP": used("DSPs"), "BRAM_tiles": used("Block RAM Tile"), "URAM": used("URAM")},
        "unrouted_nets": nets("# of routable nets") - nets("# of fully routed nets"),
        "routing_errors": nets("# of nets with routing errors"),
    }


def collect():
    verify_source()
    baseline = json.loads((ROOT / "reference/baseline_evaluation.json").read_text())
    route, final = stage_metrics("route"), stage_metrics("postroute")
    csim = json.loads((ROOT / "reports/csim_comparison.json").read_text())
    rtl = json.loads((ROOT / "reports/rtl_comparison.json").read_text())
    ii = require_ii()
    delta = {k: final["resources"][k] - baseline["resources"][k] for k in final["resources"]}
    accuracy = csim["passed"] and rtl["passed"]
    constraints = accuracy and ii == 2 and final["timing_pass"] and final["unrouted_nets"] == 0 and final["routing_errors"] == 0
    reduced = any(delta[k] < 0 for k in ["LUT", "FF", "DSP"])
    no_tradeoff = all(delta[k] <= 0 for k in delta)
    margin = final["WNS_ns"] >= baseline["WNS_ns"]
    result = {
        "experiment": "E24_sehyeon_stable_coefficients", "started_at": started_at,
        "finished_at": datetime.now().astimezone().isoformat(), "status": "COMPLETE",
        "source_commit": baseline["source_commit"], "source_changes": "18 coefficient arguments marked STABLE at top DATAFLOW; baseline arithmetic unchanged",
        "II": ii, "csim": csim, "RTL_cosim": rtl, "baseline": baseline,
        "route": route, "postroute": final, "resource_delta": delta,
        "target_constraints_pass": constraints, "baseline_WNS_margin_preserved": margin,
        "resource_reduction": reduced, "resource_nonincrease_all_categories": no_tradeoff,
        "adoption_recommended": constraints and margin and reduced and no_tradeoff,
        "completed_tools": completed,
        "scope": "core OOC; C/RTL co-sim before physical implementation; no SDF or physical netlist simulation",
    }
    hls_reports = WORK / "prj/sol1/syn/report"
    for name in ["ResGRU_csynth.rpt", "ResGRU_csynth.xml", "Loop_LOOP_T_proc_csynth.rpt", "Loop_LOOP_T_proc_csynth.xml"]:
        shutil.copy2(hls_reports / name, ROOT / "reports" / name)
    cosim_report = WORK / "prj/sol1/sim/report/ResGRU_cosim.rpt"
    if cosim_report.exists():
        shutil.copy2(cosim_report, ROOT / "reports" / cosim_report.name)
    (ROOT / "evaluation.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    md = "# E24: 고정 계수 STABLE 지정·DATAFLOW 전달 중복 감소 — 구현 결과\n\n"
    md += "기준은 sehyeon 최종본의 2026-11-05 실제 재실행 결과입니다. E23의 산술 변경은 포함하지 않습니다. 계수 18개 인자만 실행 중 고정으로 선언했습니다.\n\n"
    md += "조건: 진행 중인 모든 호출이 완료될 때까지 가중치·bias·gating·PReLU 계수를 변경하지 않아야 합니다. IQ·출력·segment_start·은닉 상태에는 STABLE을 지정하지 않았습니다.\n\n"
    md += "| 항목 | 기준본 | E24 배선 후 AggressiveExplore | 변화 |\n|---|---:|---:|---:|\n"
    md += f"| II | 2 | {ii} | {ii-2:+d} |\n"
    md += f"| WNS(ns) | {baseline['WNS_ns']:+.3f} | {final['WNS_ns']:+.3f} | {final['WNS_ns']-baseline['WNS_ns']:+.3f} |\n"
    md += f"| STA 환산 주기(ns) | {baseline['comparison_period_ns']:.3f} | {final['comparison_period_ns']:.3f} | {final['comparison_period_ns']-baseline['comparison_period_ns']:+.3f} |\n"
    for key in delta:
        md += f"| {key} | {baseline['resources'][key]:,} | {final['resources'][key]:,} | {delta[key]:+,} |\n"
    md += f"\nC-sim·RTL co-sim은 각각 7,680샘플을 현재 참조와 Q12 코드로 비교했습니다. C-sim PASS={csim['passed']}, RTL PASS={rtl['passed']}입니다.\n\n"
    md += f"15ns setup/hold/pulse 통과={final['timing_pass']}, WNS 기준 여유 유지={margin}, 자원 감소={reduced}, 전 자원 비증가={no_tradeoff}.\n\n"
    md += f"최종 setup/hold/pulse 위반={final['failing_endpoints']}, 미배선={final['unrouted_nets']}, 배선 오류={final['routing_errors']}.\n\n"
    md += f"최초 배선 WNS {route['WNS_ns']:+.3f}ns → 배선 후 AggressiveExplore {final['WNS_ns']:+.3f}ns.\n\n"
    if result["adoption_recommended"]:
        md += "**판정: 현재 기준의 정확도·II·타이밍 여유를 유지하면서 자원이 감소해 채택 후보입니다. 원본 기준 소스는 자동 교체하지 않았습니다.**\n\n"
    else:
        md += "**판정: 결과 표의 조건을 모두 충족하는 자원 절감 후보로 자동 채택하지 않습니다. 원본 기준 소스는 유지합니다.**\n\n"
    md += "STA 환산 주기는 15ns−WNS이며 보드 실측 주기가 아닙니다. RTL co-sim은 물리 변환 전 검증이며, 최종 netlist 기능 시뮬레이션·SDF 검증은 별도로 수행하지 않았습니다.\n\n"
    md += "- [모델 코드 차이](source_changes.diff)\n- [C 비교](reports/csim_comparison.json)\n- [RTL 비교](reports/rtl_comparison.json)\n"
    md += "- [최종 타이밍](reports/postroute/timing_summary.rpt)\n- [critical paths](reports/postroute/critical_paths.rpt)\n- [최종 자원](reports/postroute/utilization.rpt)\n"
    md += "- [배선 상태](reports/postroute/route_status.rpt)\n- [DRC](reports/postroute/drc.rpt)\n- [최종 checkpoint](checkpoints/postroute.dcp)\n- [JSON](evaluation.json)\n"
    (ROOT / "RESULTS.md").write_text(md, encoding="utf-8")
    print(json.dumps({"status": "COMPLETE", "result": str(ROOT / "RESULTS.md"),
                      "WNS_ns": final["WNS_ns"], "resources": final["resources"],
                      "adoption_recommended": result["adoption_recommended"]}), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--from-stage", choices=STAGES, default="synthesis")
    args = parser.parse_args()
    verify_source()
    start = STAGES.index(args.from_stage)
    if start <= 0:
        execute("synthesis", HLS, "synthesize.tcl")
    require_ii()
    if start <= 1:
        execute("cosim", HLS, "cosim.tcl")
    if start <= 2:
        execute("export", HLS, "export.tcl")
    if start <= 3:
        execute("implementation", VIVADO, "implement.tcl")
    collect()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        error = traceback.format_exc()
        failure = {"status": "FAILED", "error": error, "completed_tools": completed,
                   "finished_at": datetime.now().astimezone().isoformat()}
        (ROOT / "evaluation.json").write_text(json.dumps(failure, indent=2) + "\n", encoding="utf-8")
        (ROOT / "RESULTS.md").write_text("# E24 실행 결과 — 실패\n\n실행이 중단됐으며 implementation 성공 결과가 아닙니다.\n\n```text\n" + error + "```\n", encoding="utf-8")
        raise
