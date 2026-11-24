"""Recreate native HLS C/RTL checks using the archived v5/v5.2 RTL."""
from pathlib import Path
from datetime import datetime
import json
import os
import re
import shutil
import subprocess
import traceback
import xml.etree.ElementTree as ET
from verify import ROOT,integrity,compare,transactions

WORK=ROOT/'build'


def tool():
    name=os.environ.get('V52_HLS') or shutil.which('vitis_hls')
    fallback=Path('C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat')
    if not name and fallback.exists():name=str(fallback)
    if not name:raise RuntimeError('Set V52_HLS to Vitis HLS 2024.1 or use its configured command prompt')
    return name


def main():
    verified=integrity()
    if (WORK/'prj').exists():raise RuntimeError('Existing build/prj; use a fresh release copy/build directory')
    (WORK/'logs').mkdir(parents=True,exist_ok=True)
    hls=tool();result={'status':'RUNNING','verified_files':verified,'started_at':datetime.now().astimezone().isoformat()}
    def execute(tag,args,cwd=ROOT,env=None):
        command=[hls,*[str(x) for x in args]]
        if os.name=='nt' and Path(hls).suffix.lower() in ['.bat','.cmd']:command=['cmd.exe','/d','/c',*command]
        flags={'creationflags':subprocess.CREATE_NO_WINDOW} if os.name=='nt' else {}
        environment={**os.environ,**(env or {})}
        runtime=Path('C:/Xilinx/Vitis_HLS/2024.1/tps/mingw/10.0.0/win64.o/nt/bin')
        if os.name=='nt' and runtime.exists():environment['PATH']=str(runtime)+os.pathsep+environment.get('PATH','')
        with (WORK/'logs'/(tag+'.log')).open('xb') as log:
            p=subprocess.run(command,cwd=cwd,env=environment,stdin=subprocess.DEVNULL,
                             stdout=log,stderr=subprocess.STDOUT,timeout=43200,**flags)
        if p.returncode:raise RuntimeError(tag+' failed; see build/logs/'+tag+'.log')
    try:
        execute('build',['-f',(ROOT/'scripts/hls.tcl').as_posix()],env={'V52_ACTION':'build'})
        result['csim_standard']=compare(WORK/'standard_csim.txt',ROOT/'reference/standard_expected.txt',7680)
        result['csim_stress']=compare(WORK/'stress_csim.txt',ROOT/'reference/stress_expected.txt',5120)
        loops=[]
        for f in (WORK/'prj/sol1/syn/report').glob('*_csynth.xml'):
            for n in ET.parse(f).getroot().findall('.//SummaryOfLoopLatency/*'):
                if 'LOOP_T' in n.tag and n.findtext('PipelineII'):loops.append(int(n.findtext('PipelineII')))
        if not loops or any(n!=2 for n in loops):raise RuntimeError('Expected LOOP_T II=2, got '+str(loops))
        result['HLS_loop_II']=loops
        for variant in ['control','candidate']:
            rtl=ROOT/('baseline_rtl' if variant=='control' else 'rtl')
            for kind,n in [('standard',7680),('stress',5120)]:
                tag=variant+'_'+kind
                execute(tag+'_setup',['-f',(ROOT/'scripts/hls.tcl').as_posix()],env={'V52_ACTION':'cosim_setup','V52_TAG':tag})
                sim=WORK/'prj/sol1/sim/verilog'
                for p in rtl.iterdir():
                    if p.suffix in ['.v','.vh','.dat']:shutil.copy2(p,sim/p.name)
                project=sim/'ResGRU.prj'
                lines=[l for l in project.read_text().splitlines() if not any(x in l for x in ['dataflow_monitor.sv','AESL_deadlock_detector.v'])]
                for p in rtl.glob('*.v'):
                    if not any('"'+p.name+'"' in l for l in lines):lines.append('sv xil_defaultlib "'+p.name+'"')
                project.write_text('\n'.join(lines)+'\n')
                bench=sim/'ResGRU.autotb.v';text=bench.read_text()
                for mod in ['AESL_deadlock_detector','dataflow_monitor']:
                    text,count=re.subn(r'(?m)^'+mod+r'\s+\w+\s*\(.*?\);','',text,flags=re.S)
                    if count!=1:raise RuntimeError('Unexpected observer module layout: '+mod)
                text=text.replace('endmodule','initial begin #1000000; $fatal(1,"v5.2 finite RTL timeout"); end\nendmodule',1)
                bench.write_text(text)
                script=sim/'run_sim.tcl';script.write_text(script.read_text().replace('    df_record_move','    # obsolete observation-only probes removed'))
                execute(tag+'_rtl',['run_sim.tcl'],cwd=sim)
                log=(WORK/'logs'/(tag+'_rtl.log')).read_text(errors='replace')
                if '[TB] done:' not in log or 'ERROR:' in log:raise RuntimeError('Native post-checker failed: '+tag)
                result[tag]=compare(WORK/(tag+'_out.txt'),WORK/(kind+'_csim.txt'),n)
                result[tag].update(transactions(sim/'ResGRU.performance.result.transaction.xml',n))
                (WORK/'prj/sol1/sim').rename(WORK/'prj/sol1'/('sim_'+tag))
        integrity();result['status']='PASS'
    except Exception:
        result.update(status='FAILED',error=traceback.format_exc());raise
    finally:
        result['finished_at']=datetime.now().astimezone().isoformat()
        (WORK/'functional_verification.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps(result,indent=2))


if __name__=='__main__':main()
