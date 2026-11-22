"""Read achieved HLS schedules; never infer II from a requested pragma."""
import argparse
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

def read(path):
    root=ET.parse(path).getroot()
    latency=root.find('.//SummaryOfOverallLatency')
    timing=root.find('.//SummaryOfTimingAnalysis')
    resources=root.find('.//AreaEstimates/Resources')
    loops=[]
    for loop in root.findall('.//SummaryOfLoopLatency/*'):
        loops.append({node.tag:node.text for node in loop})
    return dict(file=str(path),latency={} if latency is None else {x.tag:x.text for x in latency},
                timing={} if timing is None else {x.tag:x.text for x in timing},
                resources={} if resources is None else {x.tag:x.text for x in resources},loops=loops)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--run',type=Path,required=True)
    a=ap.parse_args()
    report=a.run/'prj/sol1/syn/report'
    assert (report/'ResFastGRNN_csynth.xml').exists(), 'Synthesis incomplete'
    reports={p.stem:read(p) for p in report.glob('*csynth.xml')}
    stage_reports={k:v for k,v in reports.items() if 'FastGRNN_PrepareStage' in k or 'FastGRNN_StateRegister' in k}
    one_cycle=bool(stage_reports) and all(v['latency'].get('Best-caseLatency')=='1' and
        v['latency'].get('Worst-caseLatency')=='1' for v in stage_reports.values())
    loop_reports=[loop for v in reports.values() for loop in v['loops'] if 'LOOP_T' in loop.get('Name','')]
    ii_two=bool(loop_reports) and all(loop.get('PipelineII')=='2' for loop in loop_reports)
    # A latency pragma alone is insufficient: verify that identity functions
    # return a directly clocked register, with no arithmetic after it.
    reg_proofs=[]
    for name in stage_reports:
        if 'StateRegister' not in name:
            continue
        module=name.removesuffix('_csynth')
        candidates=list((a.run/'prj/sol1/syn/verilog').glob('*'+module+'.v'))
        assert len(candidates)==1,(module,candidates)
        text=candidates[0].read_text()
        assignments=re.findall(r'assign\s+ap_return\s*=\s*(\w+)\s*;',text)
        assert len(assignments)==1,(module,assignments)
        signal=assignments[0]
        clocked=bool(re.search(r'always\s*@\s*\(posedge ap_clk\)',text)) and bool(re.search(r'\b'+re.escape(signal)+r'\s*<=',text))
        assert clocked, f'{module}: return is not a directly clocked register'
        reg_proofs.append(dict(module=module,registered_return=signal,rtl=str(candidates[0])))
    prepare_proofs=[]
    for name in stage_reports:
        if 'PrepareStage' not in name:
            continue
        module=name.removesuffix('_csynth')
        candidates=list((a.run/'prj/sol1/syn/verilog').glob('*'+module+'.v'))
        assert len(candidates)==1
        text=candidates[0].read_text()
        regs=re.findall(r'\b((?:npre|zpre)_\w+_reg_\d+)\s*<=',text)
        assert len(set(regs))==10, f'{module}: expected 5 z_pre + 5 n_pre registers'
        prepare_proofs.append(dict(module=module,registered_activation_inputs=sorted(set(regs)),rtl=str(candidates[0])))
    feature_report=reports.get('FastGRNN_FeatureRegister_csynth')
    assert feature_report is not None, 'Feature register was not synthesized'
    assert feature_report['latency']['Best-caseLatency']=='1'
    feature_rtl=a.run/'prj/sol1/syn/verilog/ResFastGRNN_FastGRNN_FeatureRegister.v'
    feature_text=feature_rtl.read_text()
    feature_signal=re.search(r'assign\s+ap_return\s*=\s*(\w+)\s*;',feature_text).group(1)
    assert re.search(r'\b'+feature_signal+r'\s*<=',feature_text), 'Feature return is not clocked'
    mac_report=reports['FastGRNN_InputMACRegister_csynth']
    assert mac_report['latency']['Best-caseLatency']=='1'
    mac_rtl=a.run/'prj/sol1/syn/verilog/ResFastGRNN_FastGRNN_InputMACRegister.v'
    mac_text=mac_rtl.read_text()
    mac_signal=re.search(r'assign\s+ap_return\s*=\s*(\w+)\s*;',mac_text).group(1)
    assert re.search(r'\b'+mac_signal+r'\s*<=',mac_text), 'MAC return is not clocked'
    assert re.search(r'input\s+\[89:0\]\s+bits',mac_text), 'Expected 90-bit boundary'
    out_report=reports['FastGRNN_OutputMACRegister_csynth']
    assert out_report['latency']['Best-caseLatency']=='1'
    out_rtl=a.run/'prj/sol1/syn/verilog/ResFastGRNN_FastGRNN_OutputMACRegister.v'
    out_text=out_rtl.read_text()
    out_signal=re.search(r'assign\s+ap_return\s*=\s*(\w+)\s*;',out_text).group(1)
    assert re.search(r'\b'+out_signal+r'\s*<=',out_text), 'Output MAC return is not clocked'
    assert re.search(r'input\s+\[41:0\]\s+bits',out_text), 'Expected 42-bit boundary'
    result=dict(output_mac_register_proof=dict(rtl=str(out_rtl),signal=out_signal,latency=1,payload_bits=42),
                input_mac_register_proof=dict(rtl=str(mac_rtl),signal=mac_signal,latency=1,payload_bits=90),
                requested_feedback_stages=2,each_stage_one_cycle=one_cycle,
                register_boundary_proofs=reg_proofs,
                registered_activation_inputs=prepare_proofs,
                feature_register_proof=dict(rtl=str(feature_rtl),signal=feature_signal,latency=1),
                achieved_sample_loop_ii_two=ii_two,sample_loop_reports=loop_reports,reports=reports,
                routed_timing_verified=False)
    out=a.run/'schedule_summary.json';out.write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='reports'},indent=2))

if __name__=='__main__':main()
