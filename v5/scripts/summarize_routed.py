"""Summarize completed direct-RTL Vivado runs."""
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def main():
    rows = []
    for scope in ('layer2', 'all'):
        folder = ROOT / f'prj_shared_{scope}/vivado_direct_routed'
        utilization = (folder / 'utilization.rpt').read_text()
        timing = (folder / 'timing_summary.rpt').read_text()
        route = (folder / 'route_status.rpt').read_text()
        values = [re.search(r'(?m)^\|\s*' + label + r'\s*\|\s*([\d.]+)', utilization)[1]
                  for label in (r'CLB LUTs\*?', 'CLB Registers', 'DSPs', 'Block RAM Tile')]
        slack = re.search(r'WNS\(ns\).*?\n[^\n]*\n\s*(-?[\d.]+)\s+[-\d.]+\s+\d+\s+\d+\s+(-?[\d.]+)', timing, re.S)
        errors = re.search(r'# of nets with routing errors\.*\s*:\s*(\d+)', route, re.I)
        rows.append('| ' + ' | '.join([scope, *values, *slack.groups(), errors[1] if errors else 'See route report']) + ' |')
    report = ['# v5.1 Vivado OOC 배치·배선 결과', '',
              'co-sim에서 Q12 일치를 확인한 직접 전달 RTL을 15 ns 제약으로 구현했다.', '',
              '| 후보 | LUT | 레지스터 | DSP | BRAM 타일 | WNS (ns) | WHS (ns) | 배선 오류 net |',
              '|---|---:|---:|---:|---:|---:|---:|---:|', *rows, '',
              '원본 보고서 및 체크포인트는 각 `v5/prj_shared_<scope>/vivado_direct_routed/`에 있다.', '']
    (ROOT / 'prj_routed_summary.md').write_text('\n'.join(report), encoding='utf-8')


if __name__ == '__main__':
    main()
