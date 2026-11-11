"""Current original-v3 experiments; never mix imported and local measurements."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


def render():
    lines=['# v3 진행표','','기준: 기존 v3 원본(sehyeon v2 final, a1998bd). 기준 재현 작업은 실행하지 않습니다.',
           '**II=2와 구현 후 15ns 통과는 필수 조건입니다.** 정확도·자원이 좋아도 둘 중 하나가 미달이면 채택하지 않습니다.',
           '호출 오버헤드 제외. 원본 기준: LUT 41,387 / FF 41,088 / DSP 362 / BRAM 0, 비교 주기 14.907ns. v3.2는 통과한 v3.1을 부모로 비교합니다.','',
           '| 버전 | 현재/최종 상태 | 완료 단계 | II | 구현 주기(ns) | LUT | FF | DSP |',
           '|---|---|---|---:|---:|---:|---:|---:|']
    sequence=ROOT/'results/batch/sehyeon_sequence.json'
    if sequence.exists():
        progress=json.loads(sequence.read_text(encoding='utf-8'))
        lines[6:6]=['sehyeon 순차 도입: '+str(progress.get('active_method') or progress.get('status'))+'; 마지막 채택본 '+progress['parent']+'. [단계별 판정 기록](sehyeon_sequence.json) · [실행 계획](../../docs/PLAN.md)','']
    records=[]
    for case in sorted((ROOT/'experiments').glob('v3.*')):
        p=ROOT/'results'/case.name/'state.json'
        s=json.loads(p.read_text(encoding='utf-8')) if p.exists() else {}
        records.append((case.name,s))
        t=s.get('timing',{});r=s.get('resources',{})
        phase='오류·검증 중단' if s.get('error') else s.get('disposition') or s.get('active_stage') or '대기'
        phase={'accepted':'필수 조건·자원 개선 통과','discard_pending_delete':'폐기 판정·실제 삭제 필요','discard_delete_blocked':'폐기 판정·삭제 정책 차단(파일 남음)'}.get(phase,phase)
        lines.append('| '+' | '.join([case.name,phase,','.join(s.get('completed',[])) or '—',str(s.get('loop_t_ii','—')),f"{t['period_ns']:.3f}" if t else '—',*[f'{r[k]:,.0f}' if k in r else '—' for k in ['LUT','FF','DSP']]])+' |')
    lines+=['','## 각 후보의 부모 대비 실제 자원 변화','','감소는 −, 증가는 +입니다. v3.1의 부모는 원래 v3, v3.2의 부모는 통과한 v3.1입니다. 구현 전에는 변화량을 확정하지 않습니다.','',
            '| 버전 | ΔLUT | ΔFF | ΔDSP | ΔBRAM18K |','|---|---:|---:|---:|---:|']
    for ident,s in records:
        delta=s.get('resource_delta',{});baseline=s.get('settings',{}).get('baseline_resources',{})
        cells=[]
        for k in ['LUT','FF','DSP','BRAM_18K']:
            cells.append(f'{delta[k]:+,.0f} ({delta[k]/baseline[k]*100:+.2f}%)' if k in delta and baseline.get(k) else f'{delta[k]:+,.0f}' if k in delta else '—')
        lines.append('| '+' | '.join([ident,*cells])+' |')
    lines+=['','## 정확도·동등성','','| 버전 | 독립 참조 Q12 불일치 | ΔNMSE | ΔACPR 좌 | ΔACPR 우 | 전체 RTL |',
            '|---|---:|---:|---:|---:|---|']
    for ident,s in records:
        q=s.get('hls_out.txt',{});delta=q.get('pa_delta_db',{});rtl=s.get('rtl_out.txt',{})
        lines.append('| '+' | '.join([ident,str(q.get('independent_reference_q12_mismatches','—')),*[f'{delta[k]:+.4f}' if k in delta else '—' for k in ['NMSE','ACPR_L','ACPR_R']],'PASS' if rtl.get('exact_candidate_c_output') else '미측정'])+' |')
    lines+=['','PA 변화는 후보 − 기준(dB), 음수는 개선입니다. 미측정은 통과나 0을 의미하지 않습니다.',
            'v3.1은 FEx inverse 16/5 통과본, v3.2는 논문의 보정 표 seed로 NR 4→1을 시도하는 자원 우선 후보입니다. v3.2는 정확도 변화만으로 채택하지 않고 실제 자원 감소를 요구합니다. 기능 검증은 각 형식을 반영한 독립 정수 참조와 비교합니다.',
            '[실험 계획](../../docs/PLAN.md) · [v3.1 상세](../../docs/v3.1_fex_mixed_precision.md) · [v3.2 상세](../../docs/v3.2_corrected_seed.md)']
    p=ROOT/'results/batch/SUMMARY.md';p.parent.mkdir(parents=True,exist_ok=True)
    temp=p.with_suffix('.tmp');temp.write_text('\n'.join(lines)+'\n',encoding='utf-8');temp.replace(p)


if __name__=='__main__':
    render()
