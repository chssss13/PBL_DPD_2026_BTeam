"""Refresh cumulative version histories from preserved reports; no EDA runs."""
from pathlib import Path
import json
import os
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
basepath = ROOT/'v1/docs/ppa_history_template.md'
base = basepath.read_text(encoding='utf-8')
base = re.sub(r'\n<!-- history-status -->.*?<!-- /history-status -->\n', '\n', base, flags=re.S)
base = re.sub(r'\n{3,}', '\n\n', base)
newrow = '| v1.5 | 10-16 / 구현10-29 | 부호 포함 직접 조회 LUT, 이후 Vivado 구현 | −196.93 | C/Python PASS, RTL 미검증 | −43.67 / −51.82 / −48.38 | 5 | 14.853 | 13.47 | 63,884 | 52,888 | 297 | 0 | 15 ns 통과, II 실패. WNS +0.147 ns |'
base = '\n'.join(newrow if line.startswith('| v1.5 |') else line for line in base.splitlines())+'\n'
base = base.replace('배치·배선 후 PPA 측정', '배치·배선 후 PPA 측정')
status = '\n<!-- history-status -->\n최신화: 2026-11-04. 이 문서는 **v0→v1까지만** 누적한다. v1.5의 10-29 구현 결과도 반영했다.\n처리율은 호출 오버헤드를 제외하며, 구현 후 수치와 HLS 추정치를 분리한다.\nBRAM 열은 BRAM_18K 환산 개수다.\n<!-- /history-status -->\n'
base = base.replace('# PPA 이력표\n', '# PPA 이력표\n'+status, 1)
basepath.write_text(base, encoding='utf-8')

def relink(text, source, destination):
    def change(match):
        label, target = match.groups()
        if '://' in target or target.startswith('#'):
            return match[0]
        targetpath, sep, anchor = target.partition('#')
        path = os.path.relpath((source/targetpath).resolve(), destination).replace('\\', '/')
        return '['+label+']('+path+(sep+anchor if sep else '')+')'
    return re.sub(r'\[([^\]]+)\]\(([^)]+)\)', change, text)

v0row = next(line for line in base.splitlines() if line.startswith('| v0 |'))
header = next(line for line in base.splitlines() if line.startswith('| 버전 |'))
separator = next(line for line in base.splitlines() if line.startswith('|---|'))
v0text = '''# PPA 이력표 — v0

최신화: 2026-11-04. 이 문서는 v0 결과만 기록한다.
동일 팀 PC의 측정값을 사용하며 조교 환경 참고값(16.659 ns)과 구분한다.
Vitis HLS/Vivado2024.1, xczu7ev-ffvc1156-2-e, 클록15ns.
호출 오버헤드는 제외한다. 처리율 = 1000/Post-Route(ns)/II.
전력 미측정. 미측정은 —로 표시한다. BRAM은 BRAM_18K 환산 개수다.

'''+header+'\n'+separator+'\n'+v0row+'''

## 판정

II2는 만족하지만 17.129ns로15ns 타이밍 실패, PA 정확도도 실패다.
v0 재현의 C/Python 비교 PASS는 PA 정확도 통과를 의미하지 않는다.
2026-10-27 기존7680샘플 출력으로 비교를 재확인했으며 C-sim 재실행은 아니다.
HLS uncertainty는4.05ns다. 후속 버전의1ns 조건과 동일한 합성 제약 비교가 아니다.

## 근거

- [팀 PC 구현](../../v1/results/E00_v0_implementation/export_impl.rpt)
- [기능 비교](../results/compare_v0.txt), [PA 평가](../results/eval_v0.txt)
- [작업환경](작업환경_가이드.md)

## 목표

NMSE≤−43.48dB, ACPR L/R≤−50.39/−47.83dBc, II≤2, 실제15ns 타이밍 통과.
자원 도전 기준은 팀 PC v0의 LUT46646/FF49546/DSP648이다.
'''
(ROOT/'v0/docs/ppa_history_template.md').write_text(v0text, encoding='utf-8')

def number(value):
    if value is None:
        return '—'
    if isinstance(value, float) and not value.is_integer():
        return f'{value:.3f}'
    return f'{int(value):,}'

def result_row(version, folder, title):
    statefile = folder/'state.json'
    if not statefile.exists():
        return '| '+version+' | 11-04 | '+title+' | — | 미측정 | — | — | — | — | — | — | — | — | 미측정 |'
    state = json.loads(statefile.read_text())
    completed = 'impl' in state.get('completed', [])
    text = ''
    if completed:
        reports = list((folder/'implementation').rglob('*utilization_routed.rpt'))
        if reports:
            text = reports[0].read_text(errors='replace')
    def used(name):
        m = re.search(r'\|\s*'+re.escape(name)+r'\s*\|\s*([\d.]+)', text)
        return float(m[1]) if m else None
    lut, ff, dsp, tile = [used(x) for x in ['CLB LUTs','CLB Registers','DSPs','Block RAM Tile']]
    bram = tile*2 if tile is not None else None
    period = None
    if completed:
        for p in (folder/'implementation').rglob('export_impl.rpt'):
            m = re.search(r'\|\s*Post-Route\s*\|\s*([\d.]+)', p.read_text(errors='replace'))
            if m:
                period = float(m[1])
                break
    ii = state.get('loop_t_ii')
    rate = f'{1000/period/ii:.2f}' if period and ii else '—'
    accuracy = state.get('rtl_out.txt') or state.get('hls_out.txt')
    pa = f"{accuracy['nmse_db']:.2f} / {accuracy['acpr_left']:.2f} / {accuracy['acpr_right']:.2f}" if accuracy else '—'
    comparison = 'C/Python·C/RTL PASS' if state.get('rtl_out.txt') else 'C/Python PASS' if accuracy else '미측정'
    nmse = '—'
    for filename in ['rtl_out.txt.compare.log', 'hls_out.txt.compare.log']:
        p = folder/filename
        if p.exists():
            m = re.search(r'NMSE\s*:\s*(-?[\d.]+)', p.read_text())
            if m:
                nmse = m[1]
                break
    timing = state.get('timing')
    note = ('15 ns PASS' if timing['pass_15ns'] else '15 ns FAIL')+f"; WNS {timing['wns_ns']:+.3f} ns" if timing else '구현 진행 중; 최종 타이밍·자원 미확정'
    if state.get('disposition') == 'discarded':
        note += '; 사용자 요청으로 폐기'
    cells = [version,'11-04',title,nmse,comparison,pa,str(ii) if ii else '—',f'{period:.3f}' if period else '—',rate,number(lut),number(ff),number(dsp),number(bram),note]
    return '| '+' | '.join(cells)+' |'

v2rows = [result_row('v2.1',ROOT/'v2/results/v2.1','direct activation BRAM ROM'),result_row('v2.2',ROOT/'v2/results/v2.2','BRAM ROM + MAC 균형 트리')]
v3folder = ROOT/'v3/results/v3.1'
if not (v3folder/'state.json').exists():
    v3folder = ROOT/'v2/results/v2.5'
v3row = result_row('v3.1',v3folder,'hidden state: n + z·(h_prev−n)')
for version in ['v2','v3']:
    dest = ROOT/version/'docs'
    text = relink(base,basepath.parent,dest)
    text = text.replace('이 문서는 **v0→v1까지만** 누적한다.', '이 문서는 **v0→v1→v2'+('→v3' if version=='v3' else '')+'까지** 누적한다.')
    rows = v2rows+([v3row] if version=='v3' else [])
    table_end = text.index('\n\n날짜는 모두')
    text = text[:table_end]+'\n'+'\n'.join(rows)+text[table_end:]
    text += '\n## 후속 버전 판정 및 근거\n\n'
    text += '- v2.1은 정확도·II2 유지,16.850ns로 타이밍 실패. v2.2는14.885ns로15ns 통과.\n'
    text += '- v2.3/v2.4는 개선이 없어 폐기했다. 누적 PPA 표의 채택 후보에서 제외한다.\n'
    text += '- v2의 최종 기준은 v2.2다. v1 대비 타이밍·자원 비교는 구현 후 값으로 한다.\n'
    text += '- 목표15ns 기준 II2의 정상상태 처리율은33.333MSps다. 표의 처리율은 구현 후 주기에서 환산한 값이다.\n'
    v2prefix = '../results' if version=='v2' else '../../v2/results'
    text += f'- v2 근거: [v2.1 state]({v2prefix}/v2.1/state.json), [v2.2 state]({v2prefix}/v2.2/state.json).\n'
    text += '\n## 후속 HLS 추정 자원 — 구현 후 값과 혼합 금지\n\n| 후보 | LUT | FF | DSP | BRAM_18K |\n|---|---:|---:|---:|---:|\n'
    folders=[('v2.1',ROOT/'v2/results/v2.1'),('v2.2',ROOT/'v2/results/v2.2')]+([('v3.1',v3folder)] if version=='v3' else [])
    for name,folder in folders:
        p=folder/'synthesis/ResGRU_csynth.xml'
        if p.exists():
            resources=ET.parse(p).find('.//AreaEstimates/Resources')
            data={c.tag:int(c.text) for c in resources}
            text+='| '+name+' | '+' | '.join(number(data[k]) for k in ['LUT','FF','DSP','BRAM_18K'])+' |\n'
    if version=='v3':
        text+='\nv3.1은 실행 당시 새 v2.5로 명명됐으나 v3으로 이관한다. 과거 보존본 repro_v2_5와 별개다.\n'
        text+='v3.1은 구현·이관 완료 후15ns 실패로 폐기했다. 소스·결과는 실패 이력으로 보존한다.\n'
    (dest/'ppa_history_template.md').write_text(text,encoding='utf-8')

guide=(ROOT/'v0/docs/작업환경_가이드.md').read_text(encoding='utf-8')
for version in ['v1','v2','v3']:
    prefix=f'''# {version} 작업환경 안내

공통 설치·셸·가상환경 안내는 아래 v0 배포 가이드를 복사한 것이다.
실제 후보 실행은 본 버전 README와 scripts를 우선한다. 아래 v0 예제는 원본 재현용이다.
현재 환경: Windows, Vitis HLS/Vivado2024.1, xczu7ev-ffvc1156-2-e, 목표15ns.
Python: `C:/Project/venv_dpd/Scripts/python.exe`.
구현은 한 번에 하나씩 실행한다. 호출 오버헤드는 목표 판정에서 제외한다.
이 버전의 누적 결과는 [PPA 이력표](ppa_history_template.md)를 확인한다.

'''
    commands={'v1':'v1/scripts/run_ii2_candidate.cmd','v2':'C:/Project/venv_dpd/Scripts/python.exe v2/scripts/run_version.py v2.2','v3':'C:/Project/venv_dpd/Scripts/python.exe v3/scripts/run_version.py v3.1'}
    if version == 'v3':
        prefix+='v3.1은15ns 타이밍 실패로 폐기했다. 재실행하지 않으며 결과만 열람한다.\n\n---\n\n'
    else:
        prefix+='저장소 루트 기준 재현 명령: `'+commands[version]+'`.\n기존 결과가 있거나 구현 진행 중이면 중복 실행하지 않는다.\n\n---\n\n'
    (ROOT/version/'docs/작업환경_가이드.md').write_text(prefix+relink(guide,ROOT/'v0/docs',ROOT/version/'docs'),encoding='utf-8')
print('Updated v0/v1/v2/v3 cumulative histories and v1/v2/v3 environment guides.')
