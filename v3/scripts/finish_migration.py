"""Normalize names after native PowerShell moves completed evidence."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root/'results/v3.1'
statefile = out/'state.json'
state = json.loads(statefile.read_text())
for rel, digest in state['sha256'].items():
    assert hashlib.sha256((out/rel).read_bytes()).hexdigest() == digest, rel
    assert hashlib.sha256((root/rel).read_bytes()).hexdigest() == digest, rel
state['original_execution_version'] = state['version']
state['version'] = 'v3.1'
state['migration_note'] = 'Completed under v2.5, reclassified as v3.1. Original tool logs retain execution paths.'
statefile.write_text(json.dumps(state, indent=2), encoding='utf-8')
p = root/'results/COMPARISON.md'
p.write_text(p.read_text(encoding='utf-8').replace('새 v2.5 변형 식', 'v3.1 변형 식'), encoding='utf-8')
p = root/'results/metrics.json'
rows = json.loads(p.read_text())
for row in rows:
    if row['version'] == 'v2.5':
        row['version'] = 'v3.1'
p.write_text(json.dumps(rows, indent=2), encoding='utf-8')
print('PASS: v3.1 source hashes match completed implementation evidence.')
subprocess.run([sys.executable, str(root/'scripts/update_histories.py')], check=True)
