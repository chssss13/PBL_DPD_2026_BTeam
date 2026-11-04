"""Sequential gated HLS flow; no background queue or evidence overwrites."""
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
import xml.etree.ElementTree as ET

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import hw_ref as hw


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('version', choices=['v2.1', 'v2.2'])
    ap.add_argument('--resume', action='store_true')
    a = ap.parse_args()
    if ROOT.name != 'v2' and a.version != 'v2.5':
        ap.error('The historical reproduction uses v2.5 only')
    hidden_rewrite = ROOT.name == 'v2' and a.version == 'v2.5'
    tree = a.version != 'v2.1'
    out = ROOT / 'results' / a.version
    if out.exists() and not a.resume:
        raise RuntimeError('Result directory exists; use --resume')
    out.mkdir(parents=True, exist_ok=True)
    statefile = out / 'state.json'
    state = json.loads(statefile.read_text()) if statefile.exists() else {'version': a.version, 'completed': []}
    if state.get('rejected_reason'):
        print(state['rejected_reason'], flush=True)
        return

    def save():
        statefile.write_text(json.dumps(state, indent=2), encoding='utf-8')

    def command(args, log, cwd=ROOT, env=None):
        print('RUN', log.name, flush=True)
        with log.open('w', encoding='utf-8') as f:
            p = subprocess.run([str(x) for x in args], cwd=cwd, env=env, stdout=f, stderr=subprocess.STDOUT)
        if p.returncode:
            raise RuntimeError(f'{log.name}: exit {p.returncode}')

    def quality(filename):
        h, r = np.loadtxt(out / filename), np.loadtxt(out / 'ref.txt')
        assert h.shape == r.shape == (7680, 2), (h.shape, r.shape)
        assert np.isfinite(h).all() and np.isfinite(r).all()
        mismatch = int(np.count_nonzero(np.rint(h*8192) != np.rint(r*8192)))
        assert mismatch == 0, f'{mismatch} fixed-point words differ'
        command([sys.executable, ROOT/'tools/compare_out.py', out/filename, out/'ref.txt', '--nmse_max', '-120'], out/(filename+'.compare.log'))
        assert (out/(filename+'.compare.log')).read_text().strip().splitlines()[-1] == 'PASS'
        log = out/(filename+'.pa.log')
        command([sys.executable, ROOT/'tools/eval_pa.py', '--pa', 'save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt', out/filename], log, ROOT/'opendpd_min')
        rows = [s.split() for s in log.read_text().splitlines() if s.strip().startswith(filename)]
        assert rows, 'PA result missing'
        nmse, evm, left, right = map(float, rows[-1][2:6])
        assert nmse <= -43.48 and left <= -50.39 and right <= -47.83, rows[-1]
        state[filename] = dict(words_mismatch=mismatch, nmse_db=nmse, evm_db=evm, acpr_left=left, acpr_right=right)

    try:
        if 'snapshot' not in state['completed']:
            shutil.copytree(ROOT/'src', out/'src', dirs_exist_ok=True)
            shutil.copy2(ROOT/'tb/tb_resgru.cpp', out/'tb_resgru.cpp')
            if hidden_rewrite:
                source = out/'src/gru_cell.h'
                text = source.read_text(encoding='utf-8')
                original = 'h_next[i] = one_minus_z * n + z * h_prev[i];'
                assert original in text
                replacement = '''// Preserve all 13 fractional bits in h_prev - n.
        // 17/4 covers the difference of two 16/3 values without saturation.
        typedef ap_fixed<17,4,AP_RND,AP_SAT> hidden_delta_t;
        const hidden_delta_t delta = hidden_delta_t(h_prev[i]) - hidden_delta_t(n);
        h_next[i] = n + z * delta;'''
                source.write_text(text.replace(original, replacement, 1), encoding='utf-8')
            state['settings'] = dict(clock_ns=15, uncertainty_ns=1, rom=1, tree=int(tree), target_ii=2, dsp_full_reg=False)
            state['settings']['hidden_rewrite'] = hidden_rewrite
            state['sha256'] = {str(p.relative_to(out)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((out/'src').rglob('*')) if p.is_file()}
            state['completed'].append('snapshot')
            save()
        # Resume must use exactly the frozen source.
        for rel, digest in state['sha256'].items():
            assert hashlib.sha256((out/rel).read_bytes()).hexdigest() == digest, rel
        if 'reference' not in state['completed']:
            qd, qi = hw.make_q('16,3'), hw.make_q('16,8')
            def fex(i, q, mode):
                amp = qd(np.sqrt(qd(qd(i*i)+qd(q*q))))
                inv = qi(1/amp) if amp > 0 else 0
                return np.array([i, q, amp, qd(qd(amp*amp)*amp), qd(q*inv), qd(i*inv)])
            hw.fex = fex
            w, cfg = hw.load_weights(str(ROOT/'golden/weights'))
            y = hw.run_fxp(w, cfg, np.loadtxt(ROOT/'golden/vectors/dpd_in.txt'), qd, hw.make_q('16,4'), hw.make_q('32,12'), 'lut_direct', 'exact', 2560, v2_tree=tree)
            if hidden_rewrite:
                transformed = hw.run_fxp(w, cfg, np.loadtxt(ROOT/'golden/vectors/dpd_in.txt'), qd, hw.make_q('16,4'), hw.make_q('32,12'), 'lut_direct', 'exact', 2560, v2_tree=tree, v2_hidden=True)
                assert np.array_equal(np.rint(y*8192), np.rint(transformed*8192)), 'Hidden rewrite differs from original Python reference'
                np.savetxt(out/'ref_hidden.txt', transformed, fmt='%.17g')
            np.savetxt(out/'ref.txt', y, fmt='%.17g')
            state['completed'].append('reference')
            save()
        project = ROOT/('prj_step_'+a.version.replace('.', '_'))
        for stage in ['csim', 'csynth', 'cosim', 'impl']:
            if stage in state['completed']:
                continue
            state['active_stage'] = stage
            state.pop('error', None)
            save()
            env = os.environ.copy()
            env.update(RUN_OUT=out.as_posix(), RUN_PROJECT=project.as_posix(), RUN_ACTION=stage, RUN_TREE=str(int(tree)))
            marker = out/(stage+'.tool_done')
            if not marker.exists():
                command(['C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat', '-f', ROOT/'scripts/run_stage.tcl'], out/(stage+'.log'), env=env)
                marker.write_text('Tool exited successfully; validation is recorded separately in state.json.\n')
            if stage == 'csim':
                quality('hls_out.txt')
            if stage == 'csynth':
                report = project/'sol1/syn/report'
                shutil.copytree(report, out/'synthesis', dirs_exist_ok=True)
                ii = []
                for p in report.glob('*.xml'):
                    for node in ET.parse(p).iter():
                        if 'LOOP_T' in node.tag or 'LOOP_T' in node.attrib.get('name', ''):
                            ii.extend(int(x.text) for x in node.iter('PipelineII') if x.text and x.text.isdigit())
                assert ii, 'LOOP_T II evidence missing'
                state['loop_t_ii'] = max(ii)
                assert max(ii) <= 2, f'LOOP_T II {ii}'
            if stage == 'cosim':
                quality('rtl_out.txt')
                reports = list((project/'sol1/sim/report').glob('*cosim.rpt'))
                assert reports and any('Pass' in p.read_text(errors='replace') for p in reports), 'cosim PASS missing'
                shutil.copytree(project/'sol1/sim/report', out/'cosim_reports', dirs_exist_ok=True)
                text = '\n'.join(p.read_text(errors='replace') for p in reports)
                row = next(s for s in text.splitlines() if re.search(r'\|\s*Verilog\s*\|\s*Pass\s*\|', s))
                fields = [s.strip() for s in row.split('|') if s.strip()]
                latency_min, latency_avg, latency_max, interval_min, interval_avg, interval_max, total = map(int, fields[2:9])
                state['throughput'] = dict(call_samples=64, interval_min=interval_min, interval_max=interval_max,
                    clock_ns=15, call_msps=64/(interval_max*15e-3), full_test_cycles=total,
                    full_test_msps=7680/(total*15e-3), pass_call_overhead=64/(interval_max*15e-3)>=33.3,
                    pass_full_test=7680/(total*15e-3)>=33.3)
            if stage == 'impl':
                dest = out/'implementation'
                for source in [project/'sol1/impl/report', project/'sol1/impl/verilog/report']:
                    if source.exists():
                        shutil.copytree(source, dest/source.parent.name, dirs_exist_ok=True)
                files = list(dest.rglob('*.rpt'))
                timing = '\n'.join(p.read_text(errors='replace') for p in files if p.name.endswith('_timing_routed.rpt'))
                m = re.search(r'WNS\(ns\).*?\n\s*-+[^\n]*\n\s*\n?\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(\d+)\s+(\d+)\s+(-?[\d.]+)', timing, re.S)
                assert m, 'Routed timing evidence missing'
                wns, whs = float(m[1]), float(m[5])
                route = '\n'.join(p.read_text(errors='replace') for p in files if 'status_routed' in p.name.lower() or 'route_status' in p.name.lower())
                def count(pattern):
                    found = re.search(pattern+r'\.+\s*:\s*(\d+)', route, re.I)
                    assert found, pattern+' missing'
                    return int(found[1])
                errors = count('nets with routing errors')
                unrouted = count('# of routable nets')-count('# of fully routed nets')
                state['timing'] = dict(wns_ns=wns, whs_ns=whs, route_errors=errors, unrouted=unrouted, pass_15ns=wns>=0 and whs>=0 and errors==0 and unrouted==0)
            state['completed'].append(stage)
            save()
            print('DONE', stage, flush=True)
        state['active_stage'] = None
        save()
        print(json.dumps(state.get('timing'), indent=2), flush=True)
    except Exception:
        state['error'] = traceback.format_exc()
        save()
        raise


if __name__ == '__main__':
    main()
