"""Wait for the active overhead flow, then evaluate the hidden-state rewrite."""
raise SystemExit('Hidden-state experiments moved to v3/scripts/run_version.py v3.1. Do not restart under v2.')
import argparse
import ctypes
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
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
cmd = [sys.executable, str(root/'scripts/run_version.py'), 'v2.5']
if (root/'results/v2.5/state.json').exists():
    cmd.append('--resume')
raise SystemExit(subprocess.call(cmd, cwd=root.parent))
