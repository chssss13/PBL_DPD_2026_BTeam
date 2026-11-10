"""Fill the teaching assistant's original PPA form; preserve its structure."""
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def git_text(spec):
    return subprocess.check_output(['git', 'show', spec], cwd=REPO).decode('utf-8')


def update():
    template = git_text('f137df6:package/docs/ppa_history_template.md')
    historical = git_text('283c494:v2/docs/ppa_history_template.md')
    prefix, body = template.split('| v0 |', 1)
    prefix = prefix.replace('**0행은 v1 (기능 복구 버전)** 입니다.', '**기준은 v1.1 (첫 기능·정확도 검증 통과 버전)** 입니다. # 열에는 버전명을 기록합니다.')
    prefix = prefix.replace('개선률은 v1 대비로 계산합니다.', '개선률은 기준 버전 대비로 계산하며, 미측정 항목의 개선률은 산출하지 않습니다.')
    goals = '## 목표' + template.split('## 목표', 1)[1]
    originals = [line for line in historical.splitlines() if line.startswith('|')]

    def original(ident):
        matches = [line for line in originals if line.startswith('| ' + ident + ' |')]
        assert matches, ident
        return matches[0]

    def renumber(line, number, label):
        cells = line.split('|')
        cells[1] = ' ' + number + ' '
        cells[3] = ' ' + label + ': ' + cells[3].strip() + ' '
        return '|'.join(cells)

    base = original('v0')
    v1rows = [renumber(original(v), '**0**' if i == 0 else str(i), v) for i, v in enumerate(['v1.1', 'v1.2 후보 A', 'v1.3 후보 B', 'v1.4', 'v1.5'])]
    v1rows += [
        '| 5 | 10-16 | v1.6: II=2 스케줄 조정·HLS 합성·전체 RTL 검증 | −196.93 (RTL/Python) | C/Python·C/RTL PASS | −43.67 / −51.82 / −48.38 (RTL) | 2 | — | — | — | — | — | — | 실제 구현 미측정; HLS 추정 13.998 ns·LUT 243,879·FF 143,893·DSP 711·BRAM 0 |',
        '| 6 | 10-16 | v1.7: v1.6 합성 결과의 Vivado 배치·배선·PPA 측정 | −196.93 (v1.6 RTL/Python) | v1.6 검증 결과 계승; 기능 변경 없음 | −43.67 / −51.82 / −48.38 (v1.6 RTL) | 2 | 24.054 | 20.79 | 66,859 | 49,754 | 711 | 0 | 실제 15 ns 실패; WNS −9.054 ns; v1.6 HLS 추정과 구분 |'
    ]
    v2rows = [renumber(original('v2.1'), '7', 'v2.1'), renumber(original('v2.2'), '8', 'v2.2')]
    v3rows = ['| 9 | 11-05 도입 | v3 기준: sehyeon v2 final (a1998bd) | 미산출; Q12 불일치 0 | 전체 참조/C·C/RTL PASS | −44.968247 / −53.345506 / −50.080454 | 2 | 14.907 | 33.542 | 41,387 | 41,088 | 362 | 0 | WNS +0.093 ns; 별도 브랜치 기준 도입 |']
    for version in sorted((p.name for p in (ROOT/'results').glob('v3.*') if p.is_dir()),key=lambda v:int(v.split('.')[1])):
        path = ROOT / 'results' / version / 'state.json'
        if not path.exists():
            continue
        s = json.loads(path.read_text(encoding='utf-8'))
        if s.get('disposition') != 'accepted' or 'impl' not in s.get('completed', []):
            continue
        q = s['hls_out.txt']; r = s['resources']; t = s['timing']
        title = {'v3.1':'FEx inverse 16/6→16/5', 'v3.2':'64항 보정 seed + 정규화 NR 1회', 'v3.3':'Multipartite sigmoid', 'v3.4':'내부 scalar FIFO 깊이 조정'}.get(version,s['settings']['title'])
        if s['settings'].get('method_description'):title=s['settings']['title']
        log = ROOT / 'results' / version / 'evidence/csim/compare_out.log'
        if not log.exists(): log = ROOT / 'results' / version / 'csim/compare_out.log'
        match = re.search(r'NMSE\s*:\s*([-+\d.]+)', log.read_text(encoding='utf-8'))
        assert match, str(log)
        number = len(v3rows) + 9
        reason = 'ACPR 개선 채택' if version == 'v3.1' else '자원 개선 채택'
        v3rows.append(f'| {number} | 11-09 | {version}: {title} | {match[1]} | C/후보 독립 참조·C/RTL PASS | {q["nmse_db"]:.6f} / {q["acpr_l_dbc"]:.6f} / {q["acpr_r_dbc"]:.6f} | {s["loop_t_ii"]} | {t["period_ns"]:.3f} | {1000/t["period_ns"]/s["loop_t_ii"]:.3f} | {r["LUT"]:,.0f} | {r["FF"]:,.0f} | {r["DSP"]:,.0f} | {r["BRAM_18K"]:,.0f} | {reason}; WNS {t["wns_ns"]:+.3f} ns |')

    note = '''측정 주석: v0 행은 조교 참고값이 아닌 팀 Windows PC의 실제 구현 값으로 채웠다. 도구는 Vitis HLS/Vivado 2024.1, FPGA는 xczu7ev-ffvc1156-2-e, 목표 클록은 15 ns다. CPU·메모리는 미확인이다. v0 HLS uncertainty는 4.05 ns, 후속 버전은 1 ns로 합성 제약이 다르다. 처리율은 호출 오버헤드를 제외한 정상상태 환산값이며 보드 실측·전력은 미측정이다. 미측정은 —로 표시한다. 기능검증 PASS와 PA 정확도·II·timing 통과는 각각 구분한다.'''
    for level in range(4):
        rows = [base]
        if level >= 1: rows += v1rows
        if level >= 2: rows += v2rows
        if level >= 3: rows += v3rows
        text = prefix + '\n'.join(rows) + '\n\n' + note + '\n\n'
        if level >= 1:
            text += 'v1.1은 C 기능·PA 정확도 검증을 통과했지만 실제 구현은 미측정이므로 이 행을 기준으로 물리 PPA 개선률을 계산하지 않는다. v1.6은 스케줄 조정·합성·RTL 검증, v1.7은 해당 합성 결과의 배치배선·PPA 측정으로 각각 별도 행에 기록한다. v1.7에 기재한 기능·PA 수치는 v1.6의 검증 결과를 계승한 것이며 신규 RTL 재평가를 뜻하지 않는다.\n\n'
        if level == 3:
            text += 'v3 기준은 우리 v2.2와 동일한 회로가 아니라 sehyeon v2 final에서 도입했다. v3.1의 부모는 v3 기준, v3.2의 부모는 v3.1이다. 표의 참조 NMSE −3028.13 dB는 불일치 0일 때 비교 스크립트의 수치 하한이며 PA 정확도가 아니다. v3.1은 정확도 개선, v3.2는 자원 개선으로 채택했다. 상세와 부모·원본 대비 변화는 [v3.1 결과](../results/v3.1/RESULTS.md)와 [v3.2 결과](../results/v3.2/RESULTS.md)에 기록한다. 미완료 후보는 이 표에 포함하지 않는다.\n\n'
        text += goals
        # User preference: identify every data row by its actual version.
        def version_label(match):
            cells = match.group(0).split('|')
            version = re.search(r'v\d+(?:\.\d+)?', cells[3])
            if version:
                cells[1] = ' ' + version.group(0) + ' '
            return '|'.join(cells)
        text = re.sub(r'^\| (?:\*\*0\*\*|\d+) \|[^\n]+', version_label, text, flags=re.M)
        # Highlight the final recorded result of each version family.
        finals = {'v0', 'v1.7', 'v2.2'}
        if level == 3:
            last = re.search(r'v3\.\d+', v3rows[-1])
            finals.add(last.group(0) if last else 'v3')
        formatted = []
        for line in text.splitlines():
            if line.startswith('|'):
                cells = [cell.strip().replace('**', '') for cell in line.split('|')[1:-1]]
                if cells and re.fullmatch(r'v\d+(?:\.\d+)?', cells[0]):
                    if cells[0] in finals:
                        cells = ['**' + cell + '**' if cell else cell for cell in cells]
                    line = '| ' + ' | '.join(cells) + ' |'
            formatted.append(line)
        text = '\n'.join(formatted) + '\n'
        destination = REPO / f'v{level}/docs/ppa_history_template.md'
        destination.write_text(text, encoding='utf-8')
        print(f'v{level}: original template, cumulative rows through v{level}')


if __name__ == '__main__':
    update()
