"""Run one candidate at a time, reviewing completed evidence before advancing."""
import argparse
import ctypes
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--wait-pid', type=int)
    args = ap.parse_args()
    if args.wait_pid:
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.restype = ctypes.c_void_p
        kernel.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
        kernel.CloseHandle.argtypes = [ctypes.c_void_p]
        handle = kernel.OpenProcess(0x100000, False, args.wait_pid)
        if handle:
            try:
                while kernel.WaitForSingleObject(handle, 5000) == 258:
                    pass
            finally:
                kernel.CloseHandle(handle)
    results = []
    for version in ['v2.1', 'v2.2']:
        out = ROOT/'results'/version
        statepath = out/'state.json'
        state = json.loads(statepath.read_text()) if statepath.exists() else {}
        # Recover report-only validation after an older in-memory runner finished.
        # This marker never asserts timing PASS; the current driver still validates reports.
        if state.get('active_stage') == 'impl' and 'impl' not in state.get('completed', []):
            log = out/'impl.log'
            if log.exists():
                text = log.read_text(errors='replace')
                if 'Finished Command export_design' in text and 'ERROR:' not in text:
                    (out/'impl.tool_done').write_text('export_design finished; revalidate preserved reports\n')
        if 'impl' not in state.get('completed', []):
            cmd = [sys.executable, str(ROOT/'scripts/run_version.py'), version]
            if statepath.exists():
                cmd.append('--resume')
            code = subprocess.call(cmd, cwd=ROOT.parent)
            if code:
                (ROOT/'results/STATUS.md').write_text(f'# 실행 상태\n\n{version} 중단. `'+version+'/state.json`의 오류와 단계 로그를 확인한다.\n후속 버전은 실행하지 않았다.\n', encoding='utf-8')
                raise SystemExit(code)
        state = json.loads(statepath.read_text())
        timing = state['timing']
        results.append({'version': version, 'ii': state['loop_t_ii'], **timing})
        (ROOT/'results/review.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
        rows = ['# 실측 결과', '', '| 버전 | II | WNS ns | WHS ns | 15 ns 판정 |', '|---|---:|---:|---:|---|']
        for r in results:
            rows.append(f"| {r['version']} | {r['ii']} | {r['wns_ns']} | {r['whs_ns']} | {'PASS' if r['pass_15ns'] else 'FAIL'} |")
        rows += ['', 'C/RTL 전체 7680샘플의 단어 일치, compare_out, PA 검증 후 기록한 결과다.', '호출 오버헤드 포함 33.3 MSps 판정은 별도 보류 상태다.']
        if timing['pass_15ns']:
            rows += ['', '현재 후보가 필수 수치/II/15 ns 게이트를 통과했으므로 추가 최적화를 중단했다.']
        else:
            rows += ['', '다음 후보는 앞 후보의 수치·II·RTL 검증을 유지하면서 MAC 트리를 추가한다.' if version == 'v2.1' else '추가 후보는 실제 routed critical path 검토 후 설계해야 한다. 아직 성공으로 판정하지 않는다.']
        (ROOT/'results/STATUS.md').write_text('\n'.join(rows)+'\n', encoding='utf-8')
        print('REVIEW', version, json.dumps(timing), flush=True)
        if timing['pass_15ns']:
            break
        assert all(s in state['completed'] for s in ['csim', 'csynth', 'cosim', 'impl'])


if __name__ == '__main__':
    main()
