"""Install cosim-verified RTL into exported IP before physical implementation."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

case=Path(sys.argv[1]).resolve()
root=Path(__file__).resolve().parents[1]
assert case.parent==root/'experiments'
solution=case/'prj_candidate/sol1'
source=solution/'syn/verilog/ResGRU.v'
verified=solution/'sim/verilog/ResGRU.v'
assert source.read_bytes()==verified.read_bytes(), 'Implementation RTL differs from cosim RTL'
assert b'FIFO_CONTROL_SHARE_V1' in source.read_bytes()
impl=solution/'impl'
target=impl/'verilog'
target.mkdir(exist_ok=True)
template=root/'experiments/v3.5/prj_candidate/sol1/impl/verilog'
for pattern in ['*.tcl','*.xdc']:
    for file in template.glob(pattern):shutil.copy2(file,target/file.name)
files=list(impl.rglob('*ResGRU.v'))
assert impl/'ip/hdl/verilog/ResGRU.v' in files
if target/'ResGRU.v' not in files:files.append(target/'ResGRU.v')
for file in files:
    # These exports must still contain the unrenamed ResGRU module.
    if file.exists():assert 'module ResGRU (' in file.read_text(), str(file)
    shutil.copy2(source,file)
(case/'implementation_rtl_audit.json').write_text(json.dumps(dict(
    source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    cosim_sha256=hashlib.sha256(verified.read_bytes()).hexdigest(),
    installed_files=[str(f.relative_to(case)) for f in files],
    implementation_script='v3.5 run_vivado.tcl/settings/extraction: identical device, clock, synthesis directive and P&R flow'),indent=2))
print('Installed cosim-verified RTL into exported IP',flush=True)
