"""Validate v3.8 and run the existing sequential candidate flow."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CASE = ROOT/'experiments/v3.8'
if not (CASE/'entry_protocol_test.json').exists():
    subprocess.run([sys.executable, ROOT/'scripts/check_entry_fusion.py'], check=True, cwd=ROOT.parent)
protocol = json.loads((CASE/'entry_protocol_test.json').read_text())
assert protocol['pass_protocol']
cfg = json.loads((CASE/'config.json').read_text())
assert not (ROOT/'results/v3.8/state.json').exists(), 'Use run_flow.py v3.8 for resumption'
for rel in cfg['candidate_sha256']:
    cfg['candidate_sha256'][rel] = hashlib.sha256((CASE/rel).read_bytes()).hexdigest()
(CASE/'config.json').write_text(json.dumps(cfg, indent=2), encoding='utf-8')
subprocess.run([sys.executable, ROOT/'scripts/run_flow.py', 'v3.8'], check=True, cwd=ROOT.parent)
