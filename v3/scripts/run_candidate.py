"""Original-v3 candidate flow: reference, PA, exact II=2, full RTL and mandatory 15ns."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import traceback
import ctypes
import time
import xml.etree.ElementTree as ET
import numpy as np
from organize_results import evidence_path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT
ap = argparse.ArgumentParser()
ap.add_argument('version', type=str)
ap.add_argument('--resume', action='store_true')
ap.add_argument('--refresh-quality', action='store_true', help='Re-evaluate existing C output without rebuilding HLS')
ap.add_argument('--stop-after', choices=['csim','csynth','cosim','impl'],default='impl')
args = ap.parse_args()
assert re.fullmatch(r'v3\.[1-9][0-9]*',args.version), 'Invalid version'
case = ROOT/'experiments'/args.version
out = ROOT/'results'/args.version
out.mkdir(parents=True,exist_ok=True)
statefile = out/'state.json'
if statefile.exists() and not args.resume:
    raise SystemExit('Results exist; use --resume. No files overwritten.')
config = json.loads((case/'config.json').read_text(encoding='utf-8'))
state = json.loads(statefile.read_text()) if statefile.exists() else dict(version=args.version,completed=[],settings=config)

def save():
    temporary=statefile.with_suffix('.tmp')
    temporary.write_text(json.dumps(state,indent=2),encoding='utf-8')
    os.replace(temporary,statefile)

def run(command, log, env=None):
    minimum=int(os.environ.get('EXPERIMENT_MIN_FREE_COMMIT_MB','0'))
    if minimum and str(command[0]).endswith('vitis_hls.bat'):
        class Memory(ctypes.Structure):
            _fields_=[('length',ctypes.c_ulong),('load',ctypes.c_ulong)]+[(n,ctypes.c_ulonglong) for n in ['total_phys','free_phys','total_page','free_page','total_virtual','free_virtual','free_extended']]
        warned=False
        while True:
            mem=Memory();mem.length=ctypes.sizeof(mem)
            if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(mem)):
                raise RuntimeError('Unable to read memory admission status')
            if mem.free_page>=minimum*1024*1024:break
            if not warned:print('WAIT memory admission',log.name,flush=True);warned=True
            time.sleep(5)
    print('RUN',log.name,flush=True)
    with log.open('w',encoding='utf-8') as stream:
        result = subprocess.run([str(x) for x in command],cwd=case,env=env,stdout=stream,stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f'{log.name}: exit {result.returncode}')

def quality(name):
    folder=evidence_path(out/('csim' if name=='hls_out.txt' else 'cosim'))
    actual=np.loadtxt(folder/name)
    comparison_output=evidence_path(ROOT/config.get('comparison_output','reference/csim_expected.txt'))
    baseline=np.loadtxt(comparison_output)
    python_ref=np.loadtxt(BASE/'reference/python_expected.txt')
    assert actual.shape==baseline.shape==python_ref.shape==(7680,2)
    assert np.isfinite(actual).all()
    result=dict(samples=7680,baseline_q12_mismatches=int(np.count_nonzero(np.rint(actual*4096)!=np.rint(baseline*4096))),python_q12_mismatches=int(np.count_nonzero(np.rint(actual*4096)!=np.rint(python_ref*4096))),baseline_max_abs_error=float(np.max(np.abs(actual-baseline))))
    if name=='hls_out.txt':
        reference=evidence_path(out/'reference/hw_ref_out.txt')
        reference.parent.mkdir(parents=True,exist_ok=True)
        reference_script=ROOT/'scripts'/config.get('reference_script','hw_ref_v3.py')
        reference_args=config.get('reference_args',['--inverse-integer',str(config.get('inverse_integer',6)),
                                                   '--inverse-width',str(config.get('inverse_width',16))])
        run([sys.executable,reference_script,*reference_args,'--out',reference,'--check',folder/name],
            folder/'independent_reference.log')
        independent=json.loads(reference.with_suffix('.json').read_text(encoding='utf-8'))
        result['independent_reference_q12_mismatches']=independent['q12_mismatches']
        result['reference_model_sha256']=independent['reference_source_sha256']
        comparison=folder/'compare_out.log'
        run([sys.executable,ROOT.parent/'v2/tools/compare_out.py',folder/name,reference,'--nmse_max',str(config['reference_nmse_max_db'])],comparison)
        ref_pass=comparison.read_text(encoding='utf-8').splitlines()[-1]=='PASS'
        exact_ok=not config['force_baseline_q12_exact'] or (result['baseline_q12_mismatches']==0 and result['python_q12_mismatches']==0)
        parent_exact=not config.get('require_parent_q12_exact') or result['baseline_q12_mismatches']==0
        result['functional_pass']=bool(ref_pass and exact_ok and parent_exact and independent['q12_mismatches']==0)
        framework=ROOT.parent/'v2/opendpd_min'
        model=framework/'save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt'
        cmd=[sys.executable,str(ROOT/'scripts/evaluate_pa.py'),'--pa',str(model),str(comparison_output),str(folder/name),'--json',str(folder/'pa_metrics.json')]
        pa_env=os.environ.copy();pa_env['PYTHONIOENCODING']='utf-8'
        with (folder/'pa.log').open('w',encoding='utf-8') as log:
            completed=subprocess.run(cmd,cwd=framework,env=pa_env,stdout=log,stderr=subprocess.STDOUT)
        assert completed.returncode==0,'PA evaluation failed; see csim/pa.log'
        rows=json.loads((folder/'pa_metrics.json').read_text(encoding='utf-8'))
        base,metrics=rows[0]['metrics'],rows[1]['metrics']
        delta={k:metrics[k]-base[k] for k in ['NMSE','ACPR_L','ACPR_R']}
        thresholds=metrics['NMSE']<=-43.48 and metrics['ACPR_L']<=-50.39 and metrics['ACPR_R']<=-47.83
        improvement=delta['NMSE']<=-0.1 or delta['ACPR_L']<=-0.2 or delta['ACPR_R']<=-0.2
        accuracy_ok=all(v<=0.02 for v in delta.values())
        benefit_candidate=config.get('resource_reduction_planned',False) or config['force_baseline_q12_exact'] or (improvement and accuracy_ok)
        result.update(nmse_db=metrics['NMSE'],acpr_l_dbc=metrics['ACPR_L'],acpr_r_dbc=metrics['ACPR_R'],pa_delta_db=delta,pa_constraints_pass=bool(thresholds),eligible_for_synthesis=bool(result['functional_pass'] and thresholds and benefit_candidate),pa_source='Fresh candidate and baseline PA, 3 x 2560 samples')
    else:
        reference=np.loadtxt(evidence_path(out/'csim/hls_out.txt'))
        assert np.array_equal(actual,reference),'RTL differs from candidate C'
        result.update(exact_candidate_c_output=True,q12_mismatches=0)
    state[name]=result
    (folder/'quality.json').write_text(json.dumps(result,indent=2),encoding='utf-8')

try:
    for rel,digest in config['candidate_sha256'].items():
        assert hashlib.sha256((case/rel).read_bytes()).hexdigest()==digest,rel
        if (out/'evidence').exists():continue
        snapshot=out/rel
        snapshot.parent.mkdir(parents=True,exist_ok=True)
        if snapshot.exists():
            assert hashlib.sha256(snapshot.read_bytes()).hexdigest()==digest,'Result snapshot changed: '+rel
        else:
            shutil.copy2(case/rel,snapshot)
    for name in ['config.json','changes.diff']:
        if not (out/'evidence').exists() and not (out/name).exists():shutil.copy2(case/name,out/name)
    if not (out/'evidence').exists() and (case/'range_audit.json').exists() and not (out/'range_audit.json').exists():
        shutil.copy2(case/'range_audit.json',out/'range_audit.json')
    baseline_manifest=json.loads((BASE/'SHA256SUMS.json').read_text(encoding='utf-8'))
    for rel,digest in baseline_manifest.items():
        assert hashlib.sha256((BASE/rel).read_bytes()).hexdigest()==digest,'Baseline changed: '+rel
    if not statefile.exists():save()
    if args.refresh_quality:
        assert 'csim' in state['completed'],'Completed C simulation required'
        quality('hls_out.txt')
        state.pop('disposition',None)
        state.pop('error',None)
        save()
        print('REFRESHED C reference and PA quality',flush=True)
        raise SystemExit(0)
    stages=['csim','csynth','cosim','impl']
    for stage in stages:
        if stages.index(stage)>stages.index(args.stop_after):break
        if stage in state['completed']:continue
        if stage!='csim':
            assert state['hls_out.txt']['eligible_for_synthesis'],'Functional/PA/benefit screening failed; synthesis prohibited'
        state['active_stage']=stage
        state.pop('error',None)
        save()
        env=os.environ.copy()
        env.update(EXPERIMENT_CASE=case.as_posix(),EXPERIMENT_STAGE=stage,EXPERIMENT_OUT=out.as_posix())
        stageout=out/stage
        stageout.mkdir(exist_ok=True)
        marker=stageout/'tool_done'
        if not marker.exists():
            run(['C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat','-f',ROOT/'scripts/candidate_stage.tcl'],stageout/(stage+'.log'),env)
            marker.write_text('Tool exited successfully; checks recorded separately.\n')
        project=case/'prj_candidate/sol1'
        if stage=='csim':quality('hls_out.txt')
        if stage=='csynth':
            report=project/'syn/report'
            if config.get('expected_scalar_fifo_depth')==1:
                assert list((project/'syn/verilog').glob('ResGRU_fifo_*_d1_*.v')), 'Scalar FIFO depth did not change to 1; no hardware benefit to evaluate'
            shutil.copytree(report,out/'csynth/reports',dirs_exist_ok=True)
            values=[]
            for p in report.glob('*.xml'):
                for node in ET.parse(p).iter():
                    if 'LOOP_T' in node.tag:
                        values.extend(int(x.text) for x in node.iter('PipelineII') if x.text and x.text.isdigit())
            assert values,'LOOP_T II missing'
            state['loop_t_ii']=max(values)
            assert max(values)==2,values
            xml=ET.parse(report/'ResGRU_csynth.xml')
            state['hls_resources']={x.tag:int(x.text) for x in xml.find('.//AreaEstimates/Resources')}
            state['hls_period_ns']=float(xml.findtext('.//EstimatedClockPeriod'))
        if stage=='cosim':
            quality('rtl_out.txt')
            report=project/'sim/report'
            text=(report/'ResGRU_cosim.rpt').read_text()
            assert re.search(r'\|\s*Verilog\s*\|\s*Pass\s*\|',text),'RTL PASS missing'
            if config.get('check_no_added_call_stalls',False):
                parent_report=evidence_path(ROOT/'results'/config.get('parent_version','v3.3')/'cosim/reports/ResGRU_cosim.rpt')
                def call_schedule(report_text):
                    row=re.search(r'\|\s*Verilog\s*\|\s*Pass\s*\|([^\n]+)',report_text)
                    return [int(x.strip()) for x in row[1].split('|') if x.strip()]
                schedule=call_schedule(text);parent_schedule=call_schedule(parent_report.read_text())
                assert schedule[4]<=parent_schedule[4] and schedule[6]<=parent_schedule[6], 'FIFO reduction introduces call stalls or longer full execution'
                state['rtl_call_schedule']=schedule
            shutil.copytree(report,out/'cosim/reports',dirs_exist_ok=True)
        if stage=='impl':
            if config.get('vivado_synth_directive'):
                generated=(project/'impl/verilog/run_vivado.tcl').read_text()
                assert '-directive '+config['vivado_synth_directive'] in generated, 'Requested synthesis setting was not applied'
            for label,source in [('summary',project/'impl/report'),('detail',project/'impl/verilog/report')]:
                if source.exists():shutil.copytree(source,out/'impl/reports'/label,dirs_exist_ok=True)
            files=list((out/'impl/reports').rglob('*.rpt'))
            timing=next(p for p in files if p.name.endswith('_timing_routed.rpt')).read_text()
            match=re.search(r'WNS\(ns\).*?\n\s*-+[^\n]*\n\s*\n?\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(\d+)\s+(\d+)\s+(-?[\d.]+)',timing,re.S)
            assert match,'Routed slack missing'
            wns,whs=float(match[1]),float(match[5])
            route=next(p for p in files if p.name.endswith('_status_routed.rpt')).read_text()
            def count(label):
                found=re.search(label+r'\.+\s*:\s*(\d+)',route,re.I)
                assert found,label
                return int(found[1])
            errors=count('nets with routing errors')
            unrouted=count('# of routable nets')-count('# of fully routed nets')
            util=next(p for p in files if p.name.endswith('_utilization_routed.rpt')).read_text()
            def used(label):return float(re.search(r'\|\s*'+re.escape(label)+r'\s*\|\s*([\d.]+)',util)[1])
            state['resources']=dict(LUT=used('CLB LUTs'),FF=used('CLB Registers'),DSP=used('DSPs'),BRAM_18K=2*used('Block RAM Tile'))
            state['timing']=dict(wns_ns=wns,whs_ns=whs,period_ns=round(15-wns,3),route_errors=errors,unrouted=unrouted,pass_15ns=wns>=0 and whs>=0 and errors==0 and unrouted==0)
        if stage=='impl':
            baseline=config['baseline_resources'];actual=state['resources']
            state['resource_delta']={k:actual[k]-v for k,v in baseline.items()}
            improvement=any((baseline[k]-actual[k])/baseline[k]>=config['min_resource_improvement_fraction'] for k in ['LUT','FF','DSP'])
            no_large_tradeoff=all(actual[k]<=v*1.01 if v else actual[k]==0 for k,v in baseline.items())
            state['mandatory_conditions_pass']=bool(state['loop_t_ii']==2 and state['timing']['pass_15ns'])
            delta=state['hls_out.txt']['pa_delta_db']
            accuracy_improvement=all(v<=0.02 for v in delta.values()) and (delta['NMSE']<=-0.1 or delta['ACPR_L']<=-0.2 or delta['ACPR_R']<=-0.2)
            benefit=(improvement and no_large_tradeoff) if config.get('resource_priority') else ((improvement and no_large_tradeoff) or accuracy_improvement)
            state['disposition']='accepted' if state['mandatory_conditions_pass'] and benefit else 'discard_pending_delete'
        state['completed'].append(stage)
        save()
        print('DONE',stage,flush=True)
        if stage==args.stop_after:break
    state['active_stage']=None
    state['review_required_before_next_version']='impl' in state['completed']
    save()
    print(json.dumps({k:state.get(k) for k in ['timing','resources','hls_resources']},indent=2),flush=True)
    if state.get('disposition')=='accepted' and 'impl' in state['completed']:
        from organize_results import organize
        organize(args.version)
except Exception as exc:
    if isinstance(exc,AssertionError):
        state['disposition']='discard_pending_delete'
    state['error']=traceback.format_exc()
    save()
    raise
