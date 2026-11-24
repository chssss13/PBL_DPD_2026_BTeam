"""Reapply the guarded E44 state sharing to a copy of the baseline RTL."""
from pathlib import Path
import shutil
from share_sync import transform
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'build/reconstructed_rtl'
if out.exists():raise RuntimeError('Refusing existing '+str(out))
out.parent.mkdir(exist_ok=True)
shutil.copytree(ROOT/'baseline_rtl',out)
audit=transform(out,ROOT/'build/reconstructed_transform.json')
for f in (ROOT/'rtl').iterdir():
    if f.suffix in ['.v','.vh','.xdc','.dat']:
        if f.suffix in ['.v','.vh','.xdc']:
            assert f.read_text(encoding='utf-8')==(out/f.name).read_text(encoding='utf-8'),f.name
        else:assert f.read_bytes()==(out/f.name).read_bytes(),f.name
print('Reconstructed RTL matches archived v5.2; state bits',audit['original_state_bits'],'->',audit['shared_state_bits'])
