"""Build detailed experiment notes from frozen evidence; never run EDA tools."""
import json
import os
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
CONFIG = '''## 공통 실행 조건

| 항목 | 설정 |
|---|---|
| 도구 / FPGA | Vitis HLS·Vivado 2024.1 / xczu7ev-ffvc1156-2-e |
| 구현 클록 / HLS uncertainty | 15 ns / 1 ns |
| DSP full register | false |
| GRU 구조 | hidden=5, 입력 투영 차원=5, 3층 |
| 호출 / 검증 / reset 간격 | 64샘플 / 전체7,680샘플 / 2,560샘플 |
| data_t / weight_t | ap_fixed<16,3> / ap_fixed<16,4> |
| accum_t | ap_fixed<32,12>, 출력 MAC은 data_t |
| 반올림 / 포화 | AP_RND / AP_SAT |
| FEx | 고정소수점 중간값, 역수16/8, sqrt·역수 내부 double 유지 |
| 활성화 | ACT_LUT=2, DIRECT_LUT_SHIFT=4 |
| 목표 | 실제 LOOP_T II≤2, routed15ns 통과, PA 정확도 유지 |

처리율은 호출 오버헤드를 제외한다. 목표15ns·II2에서33.333MSps이며,
실제 구현이15ns를 통과했을 때만 이 클록에서 달성했다고 판단한다.
`1000 / Post-Route(ns) / II`는 보고서 주기로 환산한 정상상태 처리율로,
보드 실측이나 실측 Fmax 탐색 결과가 아니다. 전력은 미측정이다.
'''
DETAILS = {
 'v2.1': ('v2', 'v2.1_bram_rom.md', 'BRAM activation ROM', 'v1.6 / v1.7', '''## 변경 목적과 코드

직접 조회 sigmoid/tanh LUT가 완전 분할된 조합 선택 회로로 구현되던 구조에서,
표 읽기를1클록 동기 BRAM ROM으로 바꿨다. 표 값과 주소 매핑은 유지한다.
입력16비트의 상위12비트가 주소이므로 각 표는4,096항목이다.

```cpp
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1
#pragma HLS BIND_STORAGE variable=activation_tables::sigmoid_direct type=rom_1p impl=bram latency=1
ap_uint<16-DIRECT_LUT_SHIFT> index = in.range(15,DIRECT_LUT_SHIFT);
ap_int<16> result = activation_tables::sigmoid_direct[index];
out.range(15,0) = result.range(15,0);
```

tanh에도 같은 방식을 적용한다. 해당 분기의 complete ARRAY_PARTITION과
LATENCY min=0 max=0을 대체했다. V2_ROM=1, V2_TREE=0이다.
MAC은 기존 직렬 포화 누산이며 hidden state 갱신식도 기존 식을 유지한다.
의도는 큰 조합 LUT 선택 경로를 메모리 경계에서 끊는 것이다.
추가 읽기 지연이 GRU 재귀 스케줄을 악화시키지 않는지도 실제 II로 확인했다.
''', '''## 해석과 채택 여부

v1.7보다 주기는24.054→16.850ns로 줄었지만, BRAM 적용만으로15ns에 도달하지 못했다.
정확도와 II2는 유지됐다. 최종 채택본이 아니라 다음 단일 변경의 비교 기준이다.
합성 추정 주기가15ns보다 작아도 배치배선 후에는 실패할 수 있다는 사례다.
'''),
 'v2.2': ('v2', 'v2.2_balanced_mac.md', 'BRAM ROM + balanced MAC', 'v2.1', '''## 변경 목적과 코드

v2.1의 BRAM ROM을 유지하고 MAC의 직렬 누산만 균형 트리로 변경했다.
V2_ROM=1, V2_TREE=1이며 register/gate 확장 옵션은 적용하지 않았다.

```cpp
accum_T sums[2*LEN];
#pragma HLS ARRAY_PARTITION variable=sums complete dim=1
for (int i=0; i<LEN; ++i) {
#pragma HLS UNROLL
    sums[LEN+i] = accum_T(x[i]*w[i]);
}
for (int i=LEN-1; i>0; --i) {
#pragma HLS UNROLL
    sums[i] = sums[2*i]+sums[2*i+1];
}
return sums[1];
```

곱별 양자화와 각 덧셈 노드의 accum_T는 유지한다. 누산 의존 경로를 줄이려는 변경이다.
포화 덧셈의 순서를 바꾸므로 모든 입력에 대한 bit-exact를 대수적 변형만으로 보장하지 않는다.
Python 참조에도 같은 트리를 적용하고 제공 전체 입력의 C/RTL 출력을 검증했다.
출력층의 누산 형식은16/3으로 남겨 모델의 기존 수치 의미를 유지한다.
''', '''## 해석과 채택 여부

v2.1보다 주기는16.850→14.885ns로1.965ns 줄었다. LUT·FF·BRAM은 감소했지만
DSP는591→711개로 증가했다. 속도 향상이 모든 자원 감소를 의미하지는 않는다.
정확도·II2·15ns routed setup/hold 및 배선 상태를 만족하므로 v2의 채택 기준이다.
실측 WNS 여유는0.115ns로 작다. 더 높은 주파수나 전력 개선을 주장하지 않는다.
과거 보존본 repro_v2_5의 활성 개선법과 같은 조합이며 결과도 같다.
'''),
 'v3.1': ('v3', 'v3.1_hidden_state.md', 'hidden state 식 재구성', 'v2.2', '''## 변경 목적과 코드

v2.2에서 hidden state 갱신식만 변경했다. BRAM ROM과 MAC 트리,
호출 제어·클록·비트폭·가중치·reset 조건은 유지한다.

기존: `h_next = (1-z)*n + z*h_prev`

변형: `h_next = n + z*(h_prev-n)`

```cpp
typedef ap_fixed<17,4,AP_RND,AP_SAT> hidden_delta_t;
const hidden_delta_t delta = hidden_delta_t(h_prev[i]) - hidden_delta_t(n);
h_next[i] = n + z * delta;
```

소스 식상 곱셈2개를1개로 줄이려는 변경이다. 차분은 소수부13비트를 보존한17/4로
선언한다. 16/3 두 값의 차 범위[-8,8)를 담으므로 중간 포화를 피할 수 있다.
차분을 기존16/3 변수에 먼저 대입하지 않는다. 최종 h_next는16비트를 유지한다.
z는 sigmoid 출력[0,1]이며 기존1-z도 같은 소수 격자에서 정확히 표현된다.
중간 곱과 합의 정밀도를 유지하면 두 식의 최종 반올림 전 값이 같다.

Python 변형 식과 기존 식의 전체 입력을 먼저 비교했다. C/RTL 역시 기존 식 참조에
대조했으므로 참조만 바꿔 차이를 감춘 검증이 아니다.
기존 사용되지 않는 one_minus_z 계산은 합성에서 제거될 수 있지만 실제 제거량은
보고서의 전체 회로 자원으로 판단한다.
''', '''## 해석과 채택 여부

실제 DSP가711→646개로65개(9.14%) 감소했다. 반면 LUT는1,206개(2.68%),
FF는1,661개(3.47%), BRAM_18K 환산은4개(7.69%) 증가했다.
구현 주기는14.885→15.410ns로0.525ns(3.53%) 늘었고 WNS가−0.410ns라15ns에 실패했다.
따라서 자원 전체가 줄었다고 표현하지 않는다. 사용자 요청으로 이 후보를 폐기했다.
현재 채택 기준은 v2.2다. v3.1은 DSP 절감과 타이밍 악화의 교환 관계를 보여주는 실험 결과다.
차분→곱셈이라는 식의 의존 관계와 물리 배선이 변하지만, 그중 어느 하나가
최악 경로 악화의 유일 원인인지는 이 단일 실험만으로 단정하지 않는다.

### 실제 최악 경로에서 확인한 변화

| 지표 | v2.2 | v3.1 | 차이 |
|---|---:|---:|---:|
| 논리 단계 | 37 | 41 | +4 |
| 논리 지연 ns | 7.570 | 8.224 | +0.654 |
| 배선 지연 ns | 6.909 | 6.772 | −0.137 |
| 데이터 경로 지연 ns | 14.479 | 14.996 | +0.517 |

두 최악 경로는 모두 tanh ROM 출력에서 sigmoid ROM 주소 입력으로 이어진다.
v3.1 경로에는 `am_submul` DSP의 PREADD 단계가 보이며, v2.2 경로는
`mac_muladd`로 시작한다. 식 재구성이 빼기·곱 연산의 하드웨어 매핑을 바꿨음을 확인할 수 있다.
현재 두 최악 경로 비교에서는 배선 지연이 오히려 줄고 논리 지연이 증가했다.
따라서 이번 타이밍 실패를 단순히 배선이 길어진 탓이라고 설명하는 것은 맞지 않는다.
다만 서로 다른 비트·물리 셀의 최악 경로 비교이므로 모든 증가분을 특정 연산 하나에
정확히 귀속하지는 않는다. 추가 반사실 실험 없이 확인할 수 있는 범위는 여기까지다.

실행 당시 이름은 새 v2.5였고 완료 후 v3.1로 이관했다. 원본 로그·프로젝트 내부에는
v2.5와 이전 절대경로가 남아 있다. 과거 repro_v2_5와는 별개다.
''')}

def evidence(version):
    owner = version.split('.')[0]
    folder = ROOT/owner/'results'/version
    state = json.loads((folder/'state.json').read_text())
    xml = ET.parse(folder/'synthesis/ResGRU_csynth.xml')
    hls = {c.tag:int(c.text) for c in xml.find('.//AreaEstimates/Resources')}
    reports = {}
    for pattern,key in [('*utilization_routed.rpt','util'),('export_impl.rpt','export'),('*timing_routed.rpt','timing'),('*timing_paths_routed.rpt','paths'),('*status_routed.rpt','route')]:
        reports[key] = next((folder/'implementation').rglob(pattern))
    util = reports['util'].read_text()
    def used(name):
        return float(re.search(r'\|\s*'+re.escape(name)+r'\s*\|\s*([\d.]+)',util)[1])
    resource = dict(LUT=used('CLB LUTs'),FF=used('CLB Registers'),DSP=used('DSPs'),BRAM_18K=2*used('Block RAM Tile'))
    periods = {name:float(value) for name,value in re.findall(r'\|\s*(Post-Synthesis|Post-Route)\s*\|\s*([\d.]+)',reports['export'].read_text())}
    cosim = folder/'cosim_reports/ResGRU_cosim.rpt'
    row=next(s for s in cosim.read_text().splitlines() if re.search(r'\|\s*Verilog\s*\|\s*Pass',s))
    fields=[s.strip() for s in row.split('|') if s.strip()]
    return dict(folder=folder,state=state,hls=hls,resources=resource,periods=periods,hls_period=float(xml.findtext('.//EstimatedClockPeriod')),reports=reports,cosim=cosim,latency=int(fields[4]),interval=int(fields[7]))

data={v:evidence(v) for v in DETAILS}
data['v1.6 / v1.7']=dict(resources=dict(LUT=66859,FF=49754,DSP=711,BRAM_18K=0),periods={'Post-Synthesis':19.266,'Post-Route':24.054})

for version,(owner,filename,title,parent,description,conclusion) in DETAILS.items():
    d=data[version]; previous=data[parent]; state=d['state']; timing=state['timing']; accuracy=state['rtl_out.txt']
    text=f'# {version}: {title}\n\n2026-11-04. 기준은 {parent}이며 한 종류의 변경만 평가했다. 전체 실행 완료.\n\n'+description+'\n'+CONFIG
    text+='\n## 기능·정확도·스케줄 검증\n\n| 항목 | 결과 |\n|---|---|\n'
    for label,value in [('C/Python·RTL/Python 출력', '전체7,680샘플,16비트 단어 불일치0'),('compare_out','C·RTL 모두 PASS'),('C/RTL cosim','Verilog PASS'),('PA NMSE / EVM',f"{accuracy['nmse_db']:.2f} / {accuracy['evm_db']:.2f} dB"),('ACPR L / R',f"{accuracy['acpr_left']:.2f} / {accuracy['acpr_right']:.2f} dBc"),('PA 기준','NMSE≤−43.48, ACPR≤−50.39/−47.83: 모두 PASS'),('실제 LOOP_T II',state['loop_t_ii']),('RTL 호출 지연',str(d['latency'])+'cycle'),('호출 간격 (참고만)',str(d['interval'])+'cycle; 목표 판정에서 제외')]:
        text+=f'| {label} | {value} |\n'
    text+='\n## 실제 구현 지표 및 기준 대비 변화\n\n| 항목 | '+parent+' | '+version+' | 변화 |\n|---|---:|---:|---:|\n'
    for key in ['LUT','FF','DSP','BRAM_18K']:
        a,b=previous['resources'][key],d['resources'][key]
        delta=b-a
        change=f'{delta:+,.0f}'+(f' ({100*delta/a:+.2f}%)' if a else '')
        text+=f'| {key} | {a:,.0f} | {b:,.0f} | {change} |\n'
    for key in ['Post-Synthesis','Post-Route']:
        a,b=previous['periods'][key],d['periods'][key]
        text+=f'| {key} (ns) | {a:.3f} | {b:.3f} | {b-a:+.3f} |\n'
    text+=f"\nWNS **{timing['wns_ns']:+.3f}ns**, WHS **{timing['whs_ns']:+.3f}ns**; routing errors={timing['route_errors']}, unrouted nets={timing['unrouted']}。\n".replace('。','.')
    text+=f"15ns 실제 판정: **{'PASS' if timing['pass_15ns'] else 'FAIL'}**. 보고 주기 환산 정상상태 처리율은 **{1000/d['periods']['Post-Route']/state['loop_t_ii']:.2f}MSps**다.\n"
    text+='BRAM은18K 환산 개수다. SRL은LUT에 포함되므로 별도로 합산하지 않는다.\n'
    text+='\n## HLS 합성 추정 — 실제 구현 자원과 구분\n\n| LUT 추정 | FF 추정 | DSP 추정 | BRAM_18K 추정 | 추정주기 ns |\n|---:|---:|---:|---:|---:|\n'
    text+='| '+' | '.join(f"{d['hls'][key]:,}" for key in ['LUT','FF','DSP','BRAM_18K'])+f" | {d['hls_period']:.3f} |\n"
    text+='\n'+conclusion
    text+='\n## 소스·보고서 및 재현\n\n'
    docdir=ROOT/owner/'docs'
    links={'실행 설정·소스 해시':d['folder']/'state.json','검증 당시 소스':d['folder']/'src','C 비교':d['folder']/'hls_out.txt.compare.log','RTL 비교':d['folder']/'rtl_out.txt.compare.log','RTL PA 평가':d['folder']/'rtl_out.txt.pa.log','RTL cosim':d['cosim'],'구현 요약':d['reports']['export'],'실제 자원':d['reports']['util'],'setup/hold':d['reports']['timing'],'최악 경로':d['reports']['paths'],'배선 상태':d['reports']['route']}
    for label,path in links.items():
        link=os.path.relpath(path,docdir).replace('\\','/')
        text+=f'- [{label}]({link})\n'
    if version == 'v3.1':
        text+='\n사용자 요청으로 폐기했으므로 자동 재실행을 차단했다. 결과와 소스는 실패 이력으로 보존한다.\n'
    else:
        text+=f'\n저장소 루트에서: `C:/Project/venv_dpd/Scripts/python.exe {owner}/scripts/run_version.py {version}`.\n'
    text+='기존 결과는 덮어쓰지 않는다. 완료 결과를 열람하려고 재실행할 필요는 없다.\n재구축은 도구의 물리 최적화에 따라 결과가 달라질 수 있으며, 원본 보고서와 체크포인트가 당시 실측 근거다.\n'
    (docdir/filename).write_text(text,encoding='utf-8')
print('Generated detailed v2.1, v2.2, v3.1 notes from frozen reports.')
