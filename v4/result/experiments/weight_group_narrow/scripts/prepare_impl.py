from pathlib import Path
import hashlib, json, shutil, re
p=Path(__file__).resolve().parent
s=p/'prj/sol1'
verified=s/'sim/verilog'
source=s/'syn/verilog/ResGRU.v'
assert source.read_bytes()==(verified/'ResGRU.v').read_bytes()
assert 'FIFO_DEPTH_ONE_V1' in source.read_text()
assert '|      Pass|' in (s/'sim/report/ResGRU_cosim.rpt').read_text()
impl=s/'impl'
target=impl/'verilog'
assert not (target/'project.runs').exists()
template=p.parent/'v35_fullrom_fifo1_area_pnr/prj/sol1/impl/verilog'
for pattern in ('*.tcl','*.xdc'):
    for f in template.glob(pattern): shutil.copy2(f,target/f.name)
script=(target/'run_vivado.tcl').read_text()
assert 'AreaOptimized_high' in script and 'set has_impl 1' in script
files=list(impl.rglob('ResGRU.v'))
assert impl/'ip/hdl/verilog/ResGRU.v' in files
installed=[]
for f in files:
    assert 'module ResGRU (' in f.read_text()
    shutil.copy2(source,f)
    # Check the reused HLS payload modules are exactly those used by co-sim.
    for payload in verified.glob('ResGRU_fifo_w*_d2_S.v'):
        candidate=f.parent/payload.name
        assert candidate.exists(),str(candidate)
        assert candidate.read_bytes()==payload.read_bytes(),str(candidate)
    installed.append(str(f.relative_to(p)))
audit=dict(cosim_top_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),installed_files=installed,
           parent_flow=str(template),synth_directive='AreaOptimized_high',clock_ns=15,
           payloads_match_cosim=True,change='Shared control32 and depth1 RTL installed after HLS IP export')
(p/'implementation_rtl_audit.json').write_text(json.dumps(audit,indent=2))
print(json.dumps(audit,indent=2),flush=True)
