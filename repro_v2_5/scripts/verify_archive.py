"""Verify frozen evidence without modifying the archive."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root/'SHA256.json').read_text())
failed = []
for name, expected in manifest.items():
    p = root/name
    if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest() != expected:
        failed.append(name)
if failed:
    raise SystemExit('FAIL: '+', '.join(failed))
print(f'PASS: {len(manifest)} preserved files match SHA256.json')
