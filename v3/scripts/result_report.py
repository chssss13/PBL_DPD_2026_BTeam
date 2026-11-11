"""Detailed, evidence-backed result documents using the v1/v2 report structure."""
import json
import re
from pathlib import Path


def write_report(root, version):
    out = root / 'results' / version
    s = json.loads((out / 'state.json').read_text(encoding='utf-8'))
    cfg = s['settings']; q = s['hls_out.txt']; t = s['timing']; r = s['resources']
    parent = cfg['baseline_resources']; delta = s['resource_delta']
    raw = out / 'evidence'
    pa = json.loads((raw / 'csim/pa_metrics.json').read_text(encoding='utf-8'))
    before, after = pa[0]['metrics'], pa[1]['metrics']
    original = json.loads((root / 'results/v3.1/evidence/csim/pa_metrics.json').read_text(encoding='utf-8'))[0]['metrics']
    methods = {
        'v3.1': ('기존 v3 기준 원본', 'FEx inverse 혼합 정밀도',
                 'FEx inverse_t의 총 비트 수 16은 유지하고 정수부를 6→5, 소수부를 10→11비트로 재배분했다. NR 초기식과 4회 반복, GRU·활성화·가중치 및 합성 옵션은 유지했다. 범위를 줄여 정밀도를 높이는 변경이므로 포화 가능성과 출력 정확도를 별도로 검증했다.',
                 'using inverse_t = ap_fixed<16,5,AP_RND,AP_SAT>; // 기존 16/6, Q10 → Q11',
                 'MP-DPD의 혼합 정밀도 원리를 FEx에 적용했다. 논문의 모델 학습이나 QAT를 재현한 것은 아니다.',
                 'ACPR 좌/우가 부모 대비 각각 0.262485/0.225698 dB 개선됐으며 NMSE 악화는 0.008198 dB다. 당시 정확도 채택 기준(ACPR 0.2 dB 이상 개선, 다른 지표 악화 0.02 dB 이하)을 통과하여 유지했다. LUT 감소는 0.50%이므로 현재의 자원 1% 기준을 만족한 사례로 해석하면 안 된다.'),
        'v3.2': ('채택된 v3.1', '보정 seed와 정규화 NR 1회',
                 'v3.1의 inverse 16/5를 유지하며 Taylor 초기식과 NR 4회를 정규화·보정 seed·NR 1회·역정규화로 대체했다. amp2의 최상위 비트로 입력을 [1,2)로 정규화하고 64항 보정 표를 사용한다. amp2=0에서는 inverse=0으로 정의한다. 나머지 GRU와 활성화 계산은 부모와 같다.',
                 '// m: 정규화된 [1,2) 입력\n// seed = 5/4 - m/4 + correction[index]\ny = y * (1.5 - 0.5 * m * y * y); // NR 1회\n// 홀수 지수 보정 46341(Q16), 역정규화 후 inverse 16/5로 반올림·포화',
                 'Simple Seed Architectures for Reciprocal and Square Root Reciprocal의 III절 polynomial-plus-correction seed가 근거다. 고정소수점 정규화·역정규화와 0 처리는 현재 FEx에 맞춘 자체 설계다. 표는 정규화 영역에서 구성하며 I/Q 데이터로 학습하지 않았다.',
                 'DSP가 7개(1.93%) 줄고 FF 증가는 0.23%에 머물러 자원 채택 기준을 만족했다. LUT는 0.96% 감소했다. NMSE는 0.163452 dB 개선됐지만 ACPR 좌/우는 0.217756/0.229578 dB 악화됐다. 공식 PA 기준을 모두 통과하므로 자원 개선 경로로 채택했다. 모든 정확도 지표가 개선된 결과는 아니다.'),
        'v3.3': ('채택된 v3.2', 'Multipartite sigmoid',
                 'sigmoid의 base+delta×fraction 보간을 기준 표와 세 부분 오프셋 표의 합으로 바꾼다. tanh와 FEx는 부모와 같다. 입력은 8비트 구간과 하위 7비트로 나누며 부분 표의 기울기 주소 정밀도를 달리한다. 최종 합에서 guard 3비트를 반올림한다.',
                 '// 부분 오프셋은 미리 계산한 표에서 조회\nresult = base[index] + ((part0[a0] + part1[a1] + part2[a2] + 4) >> 3);',
                 'Multipartite Table Methods의 부분 오프셋 분해를 적용했다. 단조성을 보존하기 위해 그룹별 최소 양자화 기울기를 사용하는 방법은 자체 변형이다.',
                 '실제 배치배선의 II·15 ns·자원·PA 조건을 함께 평가한다. 곱셈 제거 자체를 자원 절감의 증거로 취급하지 않는다.')}
    methods['v3.4'] = ('채택된 v3.3', '내부 scalar FIFO 깊이 조정',
        '외부 I/Q·가중치 입력과 모든 수치 연산을 유지하고 scalar propagation FIFO의 최소 깊이 설정만 2→1로 변경한다. DATAFLOW와 다른 종류의 버퍼는 유지한다.',
        'config_dataflow -scalar_fifo_depth 1',
        'IEEE TCAD 2020 COMBA의 dataflow 채널·directive 상호작용 분석을 참고한 실험이다. 깊이 1이라는 설정과 현재 회로의 효과는 자체 검증 대상이며 논문의 직접 결론이 아니다.',
        '부모와 전체 C/RTL 출력 일치, II=2·15 ns, 호출 정체 및 자원 감소 조건을 함께 확인한다. 작은 FIFO가 항상 안전하거나 유리하다는 뜻은 아니다.')
    if version not in methods or cfg.get('method_description'):
        methods[version] = (cfg['parent'],cfg['title'],cfg['method_description'],cfg.get('method_code','// See experiments/'+version+'/changes.diff'),cfg['paper_scope'],cfg.get('interpretation','마지막 채택본 대비 실제 자원·타이밍·PA 및 필수 조건을 평가한다.'))
    parent_name, title, method, code, scope, interpretation = methods[version]
    provenance = (f'[기법 출처: sehyeon 176b59b](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/176b59b/v3/result/v3.3). {scope}'
                  if not cfg['paper'].startswith('http') else f'[논문·기술 근거]({cfg["paper"]}). {scope}')
    if s.get('validation_inherited_from'):
        method += ' C 시뮬레이션·HLS 합성·RTL co-simulation·PA 수치는 '+s['validation_inherited_from']+'에서 검증한 동일 소스·동일 HLS RTL의 결과를 계승했다. 이 후보에서 해당 검증을 새로 실행한 값이 아니다. Vivado 합성·배치배선만 다시 실행했다.'
    lines = [f'# {version}: {title}', '',
             f'{cfg.get("experiment_date","2026-11-09")}. 기준은 **{parent_name}**이며, 아래 수치는 완료된 해당 후보의 전체 flow 결과다. 판정: **{s["disposition"]}**.', '',
             '## 변경 목적과 코드', '', method, '', '```cpp', code, '```', '',
             provenance, '',
             f'[전체 코드 변경](../../experiments/{version}/changes.diff) · [검증 소스와 설정](../../experiments/{version}/)', '',
             '## 공통 실행 조건', '', '| 항목 | 설정 |', '|---|---|',
             '| 도구 / FPGA | Vitis HLS·Vivado 2024.1 / xczu7ev-ffvc1156-2-e |',
             '| 구현 클록 / HLS uncertainty | 15 ns / 1 ns |',
             f'| DSP full register / Vivado 합성 directive | false / {cfg.get("vivado_synth_directive","sdx_optimization_effort_high")} |',
             '| GRU 구조 | hidden=5, 입력 투영 차원=5, 3층 |',
             '| 호출 / 전체 검증 / reset | 64샘플 / 7,680샘플 / 2,560샘플 |',
             '| data / weight | signed 15/3(Q12) / signed 14/4(Q10) |',
             '| 주요 GRU 누산 | 곱별 18/3 → 누산 21/6 → 최종 18/3 |',
             '| 반올림 / 포화 | AP_RND / AP_SAT; 상태 최종 변환의 범위 검증된 AP_WRAP 유지 |',
             f'| FEx inverse / NR | signed 16/5(Q11) / {"4회" if version=="v3.1" else "정규화 1회"} |',
             f'| 활성화 | {"sigmoid multipartite, tanh 256구간 보간" if int(version.split(".")[1])>=3 else "sigmoid·tanh 256구간 선형 보간"} |', '',
             '처리율은 호출 오버헤드를 제외한다. 15 ns·II=2에서 정상상태 목표는 33.333 MSps다. 보고 주기의 환산 처리율은 `1000 / 주기(ns) / II`이며, 보드 실측이나 호출 오버헤드를 포함한 처리율이 아니다. 전력은 미측정이다.', '',
             '## 기능·정확도·스케줄 검증', '', '| 항목 | 결과 |', '|---|---|',
             f'| C/독립 Python 정수 참조 | 전체 7,680샘플, Q12 성분 불일치 {q["independent_reference_q12_mismatches"]}개 |',
             f'| C/RTL co-simulation | {"Verilog PASS, 전체 C 출력과 일치" if s["rtl_out.txt"].get("exact_candidate_c_output") else "미통과"} |',
             f'| 실제 LOOP_T II | {s["loop_t_ii"]} |']
    if version == 'v3.2':
        lines.append('| 단위 연산 검증 | 표현 가능한 amp2 코드 16,384개 전수 C/독립 참조 비교 |')
    if version == 'v3.3':
        lines.append('| 단위 연산 검증 | sigmoid 입력 코드 32,768개 전수 C/독립 참조 비교 |')
    cosim = (raw / 'cosim/reports/ResGRU_cosim.rpt').read_text()
    row = re.search(r'\|\s*Verilog\s*\|\s*Pass\s*\|([^\n]+)', cosim)
    if row:
        cells = [x.strip() for x in row[1].split('|') if x.strip()]
        lines += [f'| RTL 호출 지연 min/avg/max | {" / ".join(cells[:3])} cycles |',
                  f'| RTL 호출 간격 min/avg/max（참고） | {" / ".join(cells[3:6])} cycles; 목표 판정에서 제외 |']
    lines += ['', '여기서 기능 일치는 **후보의 수치 연산을 반영한 독립 참조와 C**, 그리고 **동일 후보의 C와 RTL** 사이의 일치다. 수치 형식·근사식을 바꿨으므로 기존 v3 출력과 bit-exact라는 의미는 아니다.', '',
              '| PA 지표 | 부모 | 후보 | 부모 대비(dB) | 공식 기준 |', '|---|---:|---:|---:|---:|']
    for key, threshold in [('NMSE',-43.48),('ACPR_L',-50.39),('ACPR_R',-47.83)]:
        lines.append(f'| {key} | {before[key]:.6f} | {after[key]:.6f} | {after[key]-before[key]:+.6f} | ≤ {threshold} |')
    lines += [f'| EVM (참고) | {before["EVM"]:.6f} | {after["EVM"]:.6f} | {after["EVM"]-before["EVM"]:+.6f} | 판정 대상 아님 |', '',
              'NMSE·EVM은 dB, ACPR은 dBc다. 변화의 음수는 개선이다. PA는 제공 모델로 2,560샘플×3구간을 평가했다. 최종 수치는 C 출력의 PA 평가이며, RTL은 전체 C 출력과 일치함을 별도로 확인했다.', '',
              '## 실제 구현 지표 및 부모 대비 변화', '', '| 항목 | 부모 | 후보 | 변화 |', '|---|---:|---:|---:|']
    for key in ['LUT','FF','DSP','BRAM_18K']:
        change=f'{delta[key]:+,.0f}'
        if parent[key]: change+=f' ({delta[key]/parent[key]*100:+.2f}%)'
        lines.append(f'| {key} | {parent[key]:,.0f} | {r[key]:,.0f} | {change} |')
    bp=cfg['baseline_period_ns']
    lines += [f'| Post-Route 주기(ns) | {bp:.3f} | {t["period_ns"]:.3f} | {t["period_ns"]-bp:+.3f} |',
              f'| WNS(ns) | {cfg["baseline_wns_ns"]:+.3f} | {t["wns_ns"]:+.3f} | {t["wns_ns"]-cfg["baseline_wns_ns"]:+.3f} |', '',
              f'WHS **{t["whs_ns"]:+.3f} ns**, routing errors={t["route_errors"]}, unrouted nets={t["unrouted"]}. 실제 구현 15 ns 판정: **{"PASS" if t["pass_15ns"] else "FAIL"}**. 보고 주기 환산 정상상태 처리율은 **{1000/t["period_ns"]/s["loop_t_ii"]:.3f} MSps**다.', '',
              'BRAM은 18K 환산 값이다. SRL은 LUT에 포함되므로 별도 합산하지 않는다. HLS 추정치는 아래에 분리한다.', '',
              '## 기존 v3 기준 원본 대비 누적 변화', '', '| 항목 | v3 원본 | 후보 | 원본 대비 |', '|---|---:|---:|---:|']
    for key, value in [('LUT',41387),('FF',41088),('DSP',362),('BRAM_18K',0)]:
        d=r[key]-value; change=f'{d:+,.0f}'+(f' ({d/value*100:+.2f}%)' if value else '')
        lines.append(f'| {key} | {value:,} | {r[key]:,.0f} | {change} |')
    for key in ['NMSE','ACPR_L','ACPR_R']:
        lines.append(f'| PA {key} | {original[key]:.6f} | {after[key]:.6f} | {after[key]-original[key]:+.6f} dB |')
    lines += ['', '원본의 물리 주기는 14.907 ns다. 원본 PA 값은 동일 평가 스크립트로 기존 C 출력을 재평가한 값이며, 원본 HLS 재실행 결과가 아니다.', '',
              '## HLS 합성 추정 — 실제 구현과 구분', '', '| LUT 추정 | FF 추정 | DSP 추정 | BRAM_18K 추정 | 추정 주기(ns) |', '|---:|---:|---:|---:|---:|',
              '| '+' | '.join([*[f'{s["hls_resources"][key]:,}' for key in ['LUT','FF','DSP','BRAM_18K']],f'{s["hls_period_ns"]:.3f}'])+' |', '',
              '## 해석과 채택 판정', '', interpretation, '',
              f'15 ns 제약의 setup 여유는 {t["wns_ns"]:.3f} ns다. 더 높은 주파수의 동작이나 모든 입력에서의 모델 정확도·전력 개선을 주장하지 않는다.', '',
              '## 소스·보고서 및 재현', '',
              f'- [소스·설정·차이](../../experiments/{version}/)',
              '- [C/독립 참조 비교](evidence/csim/quality.json)',
              '- [PA 평가 전체 정밀도 수치](evidence/csim/pa_metrics.json)',
              '- [RTL 비교](evidence/cosim/quality.json) · [RTL cosim 보고서](evidence/cosim/reports/ResGRU_cosim.rpt)',
              '- [구현 요약](evidence/impl/reports/summary/verilog/export_impl.rpt)',
              '- [실제 자원](evidence/impl/reports/detail/ResGRU_utilization_routed.rpt)',
              '- [setup/hold](evidence/impl/reports/detail/ResGRU_timing_routed.rpt)',
              '- [배선 상태](evidence/impl/reports/detail/ResGRU_status_routed.rpt)',
              '- [자동화 상태·소스 해시](state.json)', '',
              f'저장소 루트에서 `C:/Project/venv_dpd/Scripts/python.exe v3/scripts/run_flow.py {version}`. 완료된 stage는 재합성하지 않고 기존 검증 상태를 사용한다. 결과 열람만 하려면 실행할 필요가 없다.', '',
              '처음부터 재구축하려면 별도 작업 복사본에서 해당 실험의 prj_candidate와 결과 경로를 새로 준비한다. 기존 결과 덮어쓰기와 실행 중 후보의 중복 실행은 피한다. PA 재평가에는 v2/opendpd_min 및 PA 모델, 기능 비교에는 v2/tools/compare_out.py가 필요하다. 물리 최적화에 따라 재실행 결과가 달라질 수 있으며, 당시 측정 근거는 위에 보존한 보고서다.']
    text='\n'.join(lines)+'\n'
    (out/'RESULTS.md').write_text(text,encoding='utf-8')
