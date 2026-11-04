"""Write the requested metrics only; never launch synthesis or experiments."""
raise SystemExit('Final hidden-state metrics are moving to v3/results/COMPARISON.md; see v3/README.md.')
import argparse
import ctypes
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
ap = argparse.ArgumentParser()
ap.add_argument('--wait-pid', type=int)
args = ap.parse_args()
if args.wait_pid:
    k = ctypes.WinDLL('kernel32', use_last_error=True)
    k.OpenProcess.restype = ctypes.c_void_p
    k.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    k.CloseHandle.argtypes = [ctypes.c_void_p]
    h = k.OpenProcess(0x100000, False, args.wait_pid)
    if h:
        try:
            while k.WaitForSingleObject(h, 5000) == 258:
                pass
        finally:
            k.CloseHandle(h)
rows = []
for version in ['v2.2', 'v2.5']:
    out = root/'results'/version
    state = json.loads((out/'state.json').read_text())
    xml = ET.parse(out/'synthesis/ResGRU_csynth.xml')
    resources = {c.tag: int(c.text) for c in xml.find('.//AreaEstimates/Resources')}
    row = dict(version=version, ii=state['loop_t_ii'], nominal_msps=1000/15/state['loop_t_ii'],
               c_accuracy=state.get('hls_out.txt'), rtl_accuracy=state.get('rtl_out.txt'),
               timing=state.get('timing'), hls_resources=resources)
    reports = list((out/'implementation').rglob('*utilization_routed.rpt'))
    if reports and 'impl' in state['completed']:
        text = reports[0].read_text(errors='replace')
        def used(name):
            match = re.search(r'\|\s*'+re.escape(name)+r'\s*\|\s*([\d.]+)', text)
            return float(match[1]) if match else None
        row['routed_resources'] = {'LUT': used('CLB LUTs'), 'FF': used('CLB Registers'), 'DSP': used('DSPs'), 'BRAM_18K_equivalent': 2*used('Block RAM Tile')}
    rows.append(row)
(root/'results/hidden_metrics.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
lines = ['# Hidden state 식 변형 결과', '', '호출 오버헤드는 목표 판정에서 제외한다. 추가 실험은 실행하지 않는다.', '',
         '| 지표 | v2.2 기존 식 | 새 v2.5 변형 식 |', '|---|---:|---:|']
def add(label, values):
    lines.append('| '+label+' | '+' | '.join(str(v) for v in values)+' |')
add('LOOP_T II', [r['ii'] for r in rows])
add('15 ns 기준 처리율 (MSps)', [round(r['nominal_msps'], 3) for r in rows])
for label, key in [('PA NMSE (dB)', 'nmse_db'), ('ACPR L (dBc)', 'acpr_left'), ('ACPR R (dBc)', 'acpr_right'), ('C/RTL 출력 단어 불일치', 'words_mismatch')]:
    add(label, [(r.get('rtl_accuracy') or {}).get(key, '미완료') for r in rows])
add('Routed WNS (ns)', [(r.get('timing') or {}).get('wns_ns', '미완료') for r in rows])
add('Routed WHS (ns)', [(r.get('timing') or {}).get('whs_ns', '미완료') for r in rows])
add('15 ns 타이밍', [('PASS' if r['timing']['pass_15ns'] else 'FAIL') if r.get('timing') else '미완료' for r in rows])
for key in ['LUT', 'FF', 'DSP', 'BRAM_18K_equivalent']:
    add('구현 후 '+key, [(r.get('routed_resources') or {}).get(key, '미완료') for r in rows])
lines += ['', 'HLS 합성 추정 자원은 hidden_metrics.json에 별도 기록한다. 구현 후 수치와 섞어 비교하지 않는다.',
          '15 ns에서 계산한 처리율은 실제 구현이 15 ns를 통과한 경우에만 달성으로 판정한다.']
(root/'results/HIDDEN_METRICS.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
print('\n'.join(lines))
