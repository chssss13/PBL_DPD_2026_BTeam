"""Sequential overhead experiments; each starts from the verified v2.2 design."""
raise SystemExit('v2.3/v2.4 were discarded by user request. This flow is disabled; use run_hidden_flow.py for new v2.5.')
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
reviews = []
for version in ['v2.3', 'v2.4']:
    statepath = ROOT/'results'/version/'state.json'
    cmd = [sys.executable, str(ROOT/'scripts/run_version.py'), version]
    if statepath.exists():
        cmd.append('--resume')
    code = subprocess.call(cmd, cwd=ROOT.parent)
    state = json.loads(statepath.read_text()) if statepath.exists() else {}
    reviews.append({'version': version, 'completed': state.get('completed'), 'throughput': state.get('throughput'), 'timing': state.get('timing'), 'rejected_reason': state.get('rejected_reason'), 'error': state.get('error')})
    (ROOT/'results/overhead_review.json').write_text(json.dumps(reviews, indent=2), encoding='utf-8')
    if code:
        raise SystemExit(code)
    if state.get('timing', {}).get('pass_15ns') and state.get('throughput', {}).get('pass_call_overhead'):
        print('PASS: routed timing and call-overhead throughput', version, flush=True)
        break
else:
    print('No passing overhead candidate yet. Review RTL control before designing v2.5.', flush=True)
