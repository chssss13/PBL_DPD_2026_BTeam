"""Validate parameter packing and create explicitly untrained C-sim fixtures."""
import copy
import hashlib
import json
from pathlib import Path
from pack_parameters import GROUPS, pack, contract

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT.parent / 'v4.6_final/src'

def make_values(shape, cursor, unit=False):
    if shape:
        return [make_values(shape[1:], cursor, unit) for _ in range(shape[0])]
    i=cursor[0]; cursor[0]+=1
    return ((i % 17)+1)/32 if unit else ((i*13)%97-48)/256

def main():
    cursor=[0]
    data={name:make_values(shape,cursor,unit) for name,shape,_,_,unit in GROUPS}
    assert cursor[0] == 237
    text=pack(data)
    assert len(text.splitlines()) == 237
    layout=contract()
    for group in layout['groups']:
        assert group['offset']+group['count'] <= 237
    for change in ['legacy', 'shape', 'coefficient', 'nan']:
        bad=copy.deepcopy(data)
        if change=='legacy': bad['W_ir']=[0]
        elif change=='shape': bad['W'][0][0].pop()
        elif change=='coefficient': bad['zeta'][0]=1.01
        else: bad['b_h'][0][0]=float('nan')
        try: pack(bad)
        except ValueError: pass
        else: raise AssertionError(f'Accepted invalid {change}')
    copied=[]
    for name in ['activations.h','activation_interp.h','activation_comb_tables.h','nnet_common.h',
                 'linear_layer.h','fex_inverse_rom.h','fxp_sqrt.h','nr_poly_tables.h']:
        a=(ROOT/'src'/name).read_bytes(); b=(BASELINE/name).read_bytes()
        assert a==b, f'Baseline helper changed: {name}'
        copied.append(dict(name=name,sha256=hashlib.sha256(a).hexdigest()))
    fixture=ROOT/'tb/fixtures'; fixture.mkdir(exist_ok=True)
    (fixture/'parameters.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
    (fixture/'parameters.txt').write_text(text,encoding='utf-8')
    samples=[(((i*7)%83-41)/256,((i*11)%79-39)/256) for i in range(128)]
    samples[0]=(0,0)
    (fixture/'input.txt').write_text(''.join(f'{i:.10f} {q:.10f}\n' for i,q in samples),encoding='utf-8')
    (fixture/'fixture_info.json').write_text(json.dumps(dict(
        trained=False, purpose='Interface/rounding regression only; not DPD performance',
        parameters=237, samples=128, baseline_helpers=copied),indent=2),encoding='utf-8')
    print('PASS: 237 values, invalid legacy/shape/coefficient/NaN rejected, 8 baseline helpers identical')

if __name__=='__main__': main()
