"""Start one detached run; no polling or progress tracker."""
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parent
if " " in str(root):
    raise SystemExit("Copy this folder to a path without spaces before running")
if (root / "build/prj").exists():
    raise SystemExit("A build already exists; use a fresh copy or python run.py --from-stage as documented")
(root / "logs").mkdir(exist_ok=True)
with (root / "logs/run.log").open("xb") as output:
    child = subprocess.Popen([sys.executable, str(root / "run.py")], cwd=root,
        stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_BREAKAWAY_FROM_JOB | subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW,
        close_fds=True)
print(f"Started background E24 worker: {child.pid}")
print(f"Final results: {root / 'RESULTS.md'}")
