"""Account for routed hierarchy exactly once; compare v3.7 with v3.8."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KEYS = ['LUT','logic_LUT','LUTRAM','SRL','FF','RAMB36','RAMB18','URAM','DSP']
LABELS = {'entry':'진입부', 'loop':'샘플 연산부', 'payload':'전달 FIFO 데이터 저장부',
          'control':'공유 FIFO 제어부', 'top':'최상위 자체 로직', 'adjustment':'계층 합계 보정'}


def sum_rows(rows):
    return {key:sum(row['resources'][key] for row in rows) for key in KEYS}


def read_version(version):
    report = ROOT/f'results/{version}/evidence/impl/reports/detail/ResGRU_utilization_hierarchical_routed.rpt'
    rows, stack = [], []
    for number, line in enumerate(report.read_text().splitlines(), 1):
        if not line.startswith('|'):
            continue
        parts = line.split('|')[1:-1]
        if len(parts) != 11 or not all(p.strip().isdigit() for p in parts[2:]):
            continue
        name = parts[0].strip()
        indent = len(parts[0])-len(parts[0].lstrip())
        while stack and stack[-1]['indent'] >= indent:
            stack.pop()
        parent = stack[-1]['path'] if stack else ''
        row = dict(name=name,module=parts[1].strip(),indent=indent,parent=parent,
                   path=parent+'/'+name,line=number,
                   resources=dict(zip(KEYS,map(lambda p:int(p.strip()),parts[2:]))))
        rows.append(row)
        if not name.startswith('('):
            stack.append(row)
    top = rows[0]
    core = next(row for row in rows if row['name']=='inst')
    direct = [row for row in rows if row['parent']==core['path']]
    grouped = {key:[] for key in LABELS}
    for row in direct:
        name = row['name']
        if name == '(inst)': key='top'
        elif name == 'Block_entry_split_proc_U0': key='entry'
        elif name == 'Loop_LOOP_T_proc_U0': key='loop'
        elif name.endswith('_payload'): key='payload'
        elif name.startswith('fifo_shared_') and name.endswith('_control'): key='control'
        else: raise AssertionError(('Unclassified core child',name))
        grouped[key].append(row)
    assert core['resources']==top['resources']
    adjustment={key:core['resources'][key]-sum_rows(direct)[key] for key in KEYS}
    assert all(adjustment[key]==0 for key in KEYS if key not in ['LUT','logic_LUT']), adjustment
    grouped['adjustment']=[dict(resources=adjustment)]
    groups = {key:dict(instances=len(items),resources=sum_rows(items)) for key,items in grouped.items()}
    assert sum_rows([dict(resources=g['resources']) for g in groups.values()])==top['resources']
    loop = grouped['loop'][0]
    children = [row for row in rows if row['parent']==loop['path']]
    loop_adjustment={key:loop['resources'][key]-sum_rows(children)[key] for key in KEYS}
    assert all(loop_adjustment[key]==0 for key in KEYS if key not in ['LUT','logic_LUT']),loop_adjustment
    loop_groups = {}
    for row in children:
        name = row['name']
        if name.startswith('('): kind='self'
        elif name.startswith('flow_control_'): kind='flow_control'
        elif 'Recurrent_' in name: kind='recurrent_products'
        elif 'tanh_comb' in name: kind='tanh'
        elif 'sigmoid' in name: kind='sigmoid'
        elif 'sparsemux' in name: kind='sparsemux'
        elif 'mux' in name: kind='other_mux'
        elif 'mul' in name: kind='arithmetic'
        else: kind='other'
        loop_groups.setdefault(kind,[]).append(row)
    if any(loop_adjustment.values()):
        loop_groups['adjustment']=[dict(resources=loop_adjustment)]
    payload_groups = {label:[row for row in grouped['payload'] if row['name'].startswith('W_')==is_weight]
                      for label,is_weight in [('weight',True),('other',False)]}
    return dict(version=version,report=report.relative_to(ROOT).as_posix(),
                report_sha256=hashlib.sha256(report.read_bytes()).hexdigest(),
                total=top['resources'],groups=groups,
                loop_groups={key:dict(instances=len(items),resources=sum_rows(items)) for key,items in loop_groups.items()},
                payload_groups={key:dict(instances=len(items),resources=sum_rows(items)) for key,items in payload_groups.items()},
                loop_children=children,
                accounting='Only immediate core children, including exclusive (inst) row. Loop subtable uses immediate loop children including exclusive self row. Never add parent and descendant totals.')


def run():
    before, after = [read_version(v) for v in ['v3.7','v3.8']]
    state = json.loads((ROOT/'results/v3.8/state.json').read_text())
    for key in ['LUT','FF','DSP']:
        assert after['total'][key]==state['resources'][key]
    out = ROOT/'results/v3.8'
    (out/'AREA_BREAKDOWN.json').write_text(json.dumps(dict(parent=before,current=after),indent=2),encoding='utf-8')
    total = after['total']
    lines = ['# v3.8 LUT・FF breakdown','',
        '2026-11-16. 기존 배치·배선 완료(routed) 보고서를 집계했다. 재합성은 실행하지 않았다.', '',
        '## 전체 구역별 자원', '',
        '| 구역 | LUT | LUT 비중 | FF | FF 비중 | DSP |',
        '|---|---:|---:|---:|---:|---:|']
    # All percentages use design totals, not FPGA device capacity.
    for key in ['loop','payload','entry','top','control','adjustment']:
        r = after['groups'][key]['resources']
        lines.append(f'| {LABELS[key]} | {r["LUT"]:,} | {r["LUT"]/total["LUT"]*100:.2f}% | {r["FF"]:,} | {r["FF"]/total["FF"]*100:.2f}% | {r["DSP"]:,} |')
    lines += [f'| **전체** | **{total["LUT"]:,}** | **100%** | **{total["FF"]:,}** | **100%** | **{total["DSP"]:,}** |','',
        '상위 모듈과 하위 모듈을 중복 합산하지 않았다. FF·DSP 등은 최상위 직계 구역과 자체 로직의 합이 전체와 같다. LUT는 계층별 합과 전체의 차이를 보정 행으로 명시해 accepted state와 대조했다. Vivado 전체 보고서는 LUT combining을 반영한 조정값임을 명시한다. 이 차이를 특정 모듈의 절감으로 임의 귀속하지 않는다.', '',
        f'LUT {total["LUT"]:,}개는 logic LUT {total["logic_LUT"]:,}개와 SRL {total["SRL"]:,}개다. LUTRAM·BRAM·URAM은 0개다. SRL은 LUT에 이미 포함되며 FF에 더하지 않는다. DSP 내부 레지스터도 별도 FF로 중복 합산하지 않는다.', '',
        f'FPGA 가용량 대비 LUT 사용률은 {total["LUT"]/230400*100:.2f}%, FF 사용률은 {total["FF"]/460800*100:.2f}%다. 위 비중은 설계 내부 비중이며 물리 면적 비중으로 환산한 값은 아니다.', '',
        '## v3.7 대비 감소 위치', '',
        '| 구역 | v3.7 LUT | v3.8 LUT | ΔLUT | v3.7 FF | v3.8 FF | ΔFF |',
        '|---|---:|---:|---:|---:|---:|---:|']
    for key in ['entry','loop','payload','control','top','adjustment']:
        a,b = [v['groups'][key]['resources'] for v in [before,after]]
        lines.append(f'| {LABELS[key]} | {a["LUT"]:,} | {b["LUT"]:,} | {b["LUT"]-a["LUT"]:+,} | {a["FF"]:,} | {b["FF"]:,} | {b["FF"]-a["FF"]:+,} |')
    a,b=before['total'],after['total']
    lines += [f'| **전체** | **{a["LUT"]:,}** | **{b["LUT"]:,}** | **{b["LUT"]-a["LUT"]:+,}** | **{a["FF"]:,}** | **{b["FF"]:,}** | **{b["FF"]-a["FF"]:+,}** |','',
        'FF는 진입부에서 8,372개 감소했고 연산부에서 198개 증가해 순감소 8,174개다. FIFO payload의 FF는 그대로다. v3.8의 절감은 FIFO 한 칸을 추가로 줄인 효과가 아니라 생산자 출력 보관을 생략한 경계 변경의 결과다. LUT 변화에는 진입부 -3,710개, 공유 제어부 -510개, 연산부 -16개 및 계층 합계 보정 변화 +2개가 포함된다. 물리 최적화가 함께 달라졌으므로 전체 차이를 한 종류의 RTL 레지스터나 논리식에 직접 귀속하지 않는다.', '',
        '## FIFO 데이터 저장부', '',
        '| 인스턴스 이름 기준 | routed 모듈 수 | LUT | FF |', '|---|---:|---:|---:|']
    for key,label in [('weight','W_로 시작하는 가중치 채널'),('other','변환된 값 및 기타 채널')]:
        group=after['payload_groups'][key];r=group['resources']
        lines.append(f'| {label} | {group["instances"]} | {r["LUT"]:,} | {r["FF"]:,} |')
    lines += ['', '원래 변환 대상은 598채널이다. 표의 모듈 수는 합성 최적화 뒤 남은 계층 인스턴스 수다. 기타 채널을 모두 bias나 중복 가중치라고 해석하지 않는다. 서로 같은 값이라도 다른 호출의 데이터를 유지할 수 있으므로 잔여 FIFO 전체를 불필요한 중복으로 보지 않는다.', '',
        '## 샘플 연산부의 직계 하위 구역', '',
        '| 구역 | 보고서 행 수 | LUT | logic LUT | SRL | FF | DSP |', '|---|---:|---:|---:|---:|---:|---:|']
    names={'self':'연산부 자체 로직(하위 모듈 제외)','arithmetic':'이름에 mul이 포함된 산술 모듈','recurrent_products':'Recurrent_* 곱 함수 모듈','tanh':'tanh 함수 모듈','sigmoid':'sigmoid 함수 모듈','sparsemux':'sparsemux 모듈','other_mux':'기타 mux 모듈','flow_control':'flow-control 모듈','other':'기타 하위 모듈','adjustment':'계층 합계 보정'}
    for key,group in after['loop_groups'].items():
        r=group['resources']
        lines.append(f'| {names[key]} | {group["instances"]} | {r["LUT"]:,} | {r["logic_LUT"]:,} | {r["SRL"]:,} | {r["FF"]:,} | {r["DSP"]:,} |')
    lines += ['', '이 표는 RTL 계층/인스턴스 이름 기준이다. mul 계열 LUT를 순수 곱셈기 비용으로 단정할 수 없다. Recurrent_*와 활성화 모듈은 계층이 남은 부분만 집계했으며 전체 GRU gate 비용은 아니다. 인라인된 FEx·GRU gate·hidden state·파이프라인 저장은 자체 로직에 섞여 있어 이 보고서만으로 정확히 분리되지 않는다.', '',
        '## 다음 분석의 우선순위', '',
        '연산부의 LUT와 FF, FIFO payload의 FF를 우선 살핀다. 연산부는 routed netlist의 레지스터 이름·연결·유효 기간을 추적해야 세부 기능별 분해가 가능하다. FIFO는 소비자 저장과 값의 유지 기간을 비교하고, 가중치 변경과 호출 중첩을 보존하는지 확인해야 한다. 자원 비중 자체는 제거 가능량이 아니다.', '',
        '## 근거', '',
        '- [v3.8 routed 계층 보고서](evidence/impl/reports/detail/ResGRU_utilization_hierarchical_routed.rpt)',
        '- [v3.8 routed 전체 보고서](evidence/impl/reports/detail/ResGRU_utilization_routed.rpt)',
        '- [v3.7 routed 계층 보고서](../v3.7/evidence/impl/reports/detail/ResGRU_utilization_hierarchical_routed.rpt)',
        '- [기계 판독 집계와 소스 해시](AREA_BREAKDOWN.json)',
        '- 재생성: `C:/Project/venv_dpd/Scripts/python.exe v3/scripts/fifo_area_breakdown.py`','']
    (out/'AREA_BREAKDOWN.md').write_text('\n'.join(lines),encoding='utf-8')
    print(json.dumps(dict(total=total,groups=after['groups'],loop_groups=after['loop_groups']),indent=2))


if __name__=='__main__':
    run()
