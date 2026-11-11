"""Publish full per-version documents from measured evidence and reviewed methods."""
from pathlib import Path
import json
import re

ROOT=Path(__file__).resolve().parents[1]
DETAILS={
'v3.1': ('v3.1_fex_mixed_precision.md','FEx inverse 정밀도 재배분', '''
변경 위치는 `src/linear_layer.h`의 FEx inverse_t다. signed 16/6(Q10)을 signed 16/5(Q11)로 변경했다. 비트 수를 줄인 실험이 아니라 정수·소수 비트 배분을 바꾼 실험이다. 양의 최댓값은 약 32에서 16으로 감소하고 양자화 간격은 2⁻¹⁰에서 2⁻¹¹로 작아진다. 표현 범위를 넘으면 AP_SAT가 적용되므로 입력 범위·포화 효과를 포함해 평가했다.

Taylor 초기식과 NR 4회는 그대로 유지했다. data 15/3, weight 14/4, GRU 누산·활성화·reset·구현 전략은 변경하지 않았다. PA 개선을 정밀도 재배분의 관측 효과로 해석하되 모든 입력에서 정확도가 향상된다는 증명은 아니다.
'''),
'v3.2': ('v3.2_corrected_seed.md','보정 seed와 정규화 NR 1회', '''
변경 위치는 `src/seed_rsqrt.h`와 FEx 호출부다. v3.1의 inverse 16/5를 유지하면서 초기값 및 반복 구조만 교체했다. amp2의 최상위 비트로 입력을 [1,2)로 정규화한 뒤, `5/4−m/4`와 64항 signed 14비트 Q17 보정 표로 seed를 만든다. 정규화된 m·y는 unsigned 16/1이다.

NR은 `y=y*(1.5−0.5*m*y*y)`를 1회 수행한다. 홀수 지수 보정은 46341(Q16)을 사용하고, 역정규화 후 inverse 16/5로 반올림·포화한다. amp2=0은 inverse=0으로 정의한다. 보정 계수는 정규화 영역 전체의 오차를 대상으로 구성했으며 제공 I/Q 벡터로 학습하지 않았다.

표와 정규화 회로가 추가되므로 반복 수 감소가 곧 자원 감소라는 가정은 하지 않았다. amp2의 표현 가능한 코드 16,384개를 C/독립 참조로 전수 비교하고 전체 네트워크 PA·RTL·실제 구현을 평가했다.
'''),
'v3.3': ('v3.3_multipartite.md','sigmoid multipartite 표·덧셈 구조', '''
변경 위치는 `src/multipartite.h`와 `src/activations.h`의 sigmoid_comb다. 기존 sigmoid `base+delta×fraction`의 fabric 곱셈을 기준값 표와 세 부분 오프셋 표의 합으로 대체했다. tanh와 v3.2 FEx는 그대로다.

15비트 위치 코드에서 상위 8비트는 구간, 하위 7비트는 [3,2,2] 묶음으로 나눈다. 부분 표의 기울기 주소 정밀도는 [2,5,5]비트이고 guard는 3비트다. 그룹의 최소 양자화 기울기를 사용해 구간 경계 단조성을 유지한다. 이 기울기 선택은 논문의 전체 회로를 복제한 것이 아니라 현재 고정소수점에 맞춘 자체 적용이다.

최종 raw Q12 출력은 `base[index]+((offset+4)>>3)`다. 원래 보간과 출력이 달라질 수 있으므로 부모 bit-exact를 채택 조건으로 쓰지 않고 새 독립 참조와 C/RTL 일치·PA 기준을 사용했다. 함수 입력 32,768개 전수 시험과 전체 7,680샘플 네트워크 검증을 수행했다.
'''),
'v3.4': ('v3.4_sehyeon_incremental.md','Vivado AreaOptimized_high 적용', '''
부모는 **우리 v3.3**이다. 세현 최종본 전체로 기준을 교체한 것이 아니라 세현 commit 176b59b에서 사용한 합성 설정만 도입했다. 우리 inverse 16/5·보정 seed·NR 1회·multipartite sigmoid는 유지했다. sigmoid 대칭 표 교체는 선행 단일 후보에서 자원 기준 미달로 삭제했으므로 현재 채택본에 포함되지 않는다.

변경 위치는 `implementation_directives.tcl`이다. Vivado synth_design directive를 기본 `sdx_optimization_effort_high`에서 `AreaOptimized_high`로 변경했다. I/Q·가중치 입력, C++ 연산, 자료형, HLS uncertainty 1 ns, DSP full reg false, LOOP_T II=2 요청, 구현 클록 15 ns는 유지했다.

```tcl
config_export -vivado_synth_design_args {-directive AreaOptimized_high}
```

이 단계는 새 논문 알고리즘이 아니라 팀원 기법의 도입과 툴 설정 비교다. 면적 최적화가 timing을 보장하지 않으므로 실제 P&R로 평가했다. C·독립 참조·PA·HLS·전체 RTL도 이 후보의 실행 결과로 확인했다. WNS 여유가 +0.032 ns로 작으므로 추가 변경의 timing 결과를 별도로 확인해야 한다.
'''),
'v3.5': ('v3.5_sehyeon_incremental.md','recurrent 개별 곱의 포화 제거', '''
부모는 채택된 v3.4다. 세현 commit 176b59b의 recurrent 개별 곱 포화 제거만 추가했다. `src/gru_cell.h`의 Recurrent_Gate_MAC 및 Recurrent_Row_MAC에서 각 곱을 누산기로 변환하는 임시 형식을 AP_SAT에서 AP_WRAP으로 바꿨다.

```cpp
typedef ap_fixed<accum_T::width, accum_T::iwidth,
                 AP_RND, AP_WRAP> product_nosat_t;
acc += product_nosat_t(Recurrent_Term_Product<...>(x[i], w[i]));
```

곱 함수의 full product 29/7, 개별 변환 폭 18/3(Q15), AP_RND 반올림, 21/6 wide 누산 및 최종 18/3 변환은 유지했다. 입력 MAC과 전체 누산 포화를 일괄 제거한 실험이 아니다. 곱이 변환 범위를 넘으면 AP_WRAP과 AP_SAT의 결과가 달라질 수 있으므로 모든 입력·가중치에 대한 대수적 동등성을 주장하지 않는다.

독립 정수 참조에도 recurrent 개별 곱 WRAP을 반영하고 전체 7,680샘플에서 부모/C/독립 참조/RTL 일치를 확인했다. 이 검증 벡터의 PA 결과는 부모와 같았다. 후속 r/z bias 사전 합산은 별도 v3.6 후보로 평가했지만 15.678 ns로 실패해 삭제했다. 따라서 bias 사전 합산은 현재 최종 v3.5에 포함되지 않는다.
''')}


def main():
    for version,(filename,title,detail) in DETAILS.items():
        source=ROOT/'results'/version/'RESULTS.md'
        text=source.read_text(encoding='utf-8')
        text=re.sub(r'^# .+',f'# {version}: {title}',text,count=1)
        start=text.index('## 변경 목적과 코드')
        text=text[:start]+text[start:].replace('## 변경 목적과 코드','## 변경 목적과 코드\n\n'+detail.strip(),1)
        if version in ['v3.4','v3.5']:
            text=text.replace('```cpp\n// See experiments/'+version+'/changes.diff\n```','상세 변경은 아래의 검증 당시 diff를 확인한다.')
        # Convert every relative link from results/v3.n to docs without altering evidence.
        def link(match):
            label,target=match.groups()
            if target.startswith(('http:','https:','#')):return match.group(0)
            import os
            destination=(source.parent/target).resolve()
            return '['+label+']('+Path(os.path.relpath(destination,ROOT/'docs')).as_posix()+')'
        text=re.sub(r'\[([^\]]*)\]\(([^)]+)\)',link,text)
        text += f'\n\n통합 결과의 자동 집계본은 [RESULTS.md](../results/{version}/RESULTS.md), 버전별 소스 원본은 [experiments/{version}](../experiments/{version}/)에 있다. 이 문서는 v1·v2와 같은 형식의 버전별 상세 설명이며 실제 측정 근거는 링크된 원본 보고서를 따른다.\n'
        target=ROOT/'docs'/filename
        target.write_text(text.rstrip()+'\n',encoding='utf-8')
        for url in re.findall(r'\]\(([^)]+)\)',text):
            if not url.startswith(('http:','https:','#')):assert (target.parent/url).exists(),(version,url)
        print(version,len(text.splitlines()),'lines; local report links verified')


if __name__=='__main__':main()
