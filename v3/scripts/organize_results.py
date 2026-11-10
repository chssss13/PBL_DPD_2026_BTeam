"""One readable result per version; keep raw evidence and machine state."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def evidence_path(path):
    """Resolve a flow artifact before or after completed-result organization."""
    path = Path(path)
    if path.exists():
        return path
    try:
        relative = path.relative_to(ROOT / 'results')
    except ValueError:
        return path
    if len(relative.parts) >= 2:
        alternate = ROOT / 'results' / relative.parts[0] / 'evidence' / Path(*relative.parts[1:])
        if alternate.exists():
            return alternate
    return path


def organize(version):
    out = ROOT / 'results' / version
    case = ROOT / 'experiments' / version
    state = json.loads((out / 'state.json').read_text(encoding='utf-8'))
    assert state.get('completed') == ['csim', 'csynth', 'cosim', 'impl'], 'Only completed flows may be organized'
    assert not state.get('active_stage'), 'Active flow must not be moved'
    evidence = out / 'evidence'
    evidence.mkdir(exist_ok=True)
    for stage in ['reference', 'csim', 'csynth', 'cosim', 'impl']:
        source = out / stage
        if source.exists():
            assert not (evidence / stage).exists(), stage
            source.rename(evidence / stage)

    # Delete only proven duplicate snapshots; the authoritative case is retained.
    duplicates = []
    for name in ['src', 'tb', 'config.json', 'changes.diff', 'range_audit.json', 'inverse_expected.txt', 'sigmoid_expected.txt', 'multipartite.json']:
        source = out / name
        if not source.exists():
            continue
        files = list(source.rglob('*')) if source.is_dir() else [source]
        for file in files:
            if file.is_file():
                original = case / file.relative_to(out)
                assert original.is_file(), str(original)
                assert hashlib.sha256(file.read_bytes()).digest() == hashlib.sha256(original.read_bytes()).digest(), str(file)
        duplicates.append(source)

    logs = evidence / 'flow'
    for source in out.glob('flow_*.log'):
        logs.mkdir(exist_ok=True)
        try:
            source.rename(logs / source.name)
        except PermissionError:
            # The parent flow holds its current stage log open until exit.
            # run_flow calls organize again after closing that handle.
            continue

    from result_report import write_report
    write_report(ROOT, version)
    from update_history import update
    update()
    if duplicates:
        # Native PowerShell only, with checked absolute literal paths, no Force.
        commands = []
        for target in duplicates:
            target = target.resolve()
            assert target.is_relative_to(out.resolve()) and target != out.resolve()
            literal = str(target).replace("'", "''")
            commands.append(f"Remove-Item -LiteralPath '{literal}'" + (' -Recurse' if target.is_dir() else ''))
        subprocess.run(['powershell', '-NoProfile', '-Command', '\n'.join(commands)], check=True)
    print(f'{version}: RESULTS.md + state.json + evidence; duplicate snapshots removed')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('versions', nargs='+')
    for version in ap.parse_args().versions:
        import re
        assert re.fullmatch(r'v3\.[1-9][0-9]*',version)
        organize(version)
