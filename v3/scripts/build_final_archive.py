"""Build the final handoff ZIP in the structure of v3_hyeonseo.zip."""
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
NAME='v3_fin_hyeonseo'
OUTPUT=ROOT/(NAME+'.zip')
EXCLUDED={'__pycache__','.Xil','.git','cache','checkpoints','protocol_test','entry_protocol_test'}


def excluded(path):
    return any(p in EXCLUDED or p.startswith('prj_') for p in path.parts) or path.suffix.lower() in {'.pyc','.pid','.dcp','.wdb','.pb'}


def main():
    assert not OUTPUT.exists(), 'Archive exists; refusing overwrite'
    parent_zip=ROOT/'v3_hyeonseo.zip'
    with zipfile.ZipFile(parent_zip) as old:
        assert all(n.startswith('v3_hyeonseo/') for n in old.namelist())
    states={v:json.loads((ROOT/f'v3/results/{v}/state.json').read_text(encoding='utf-8')) for v in [f'v3.{i}' for i in range(1,9)]}
    assert all(s['disposition']=='accepted' and s['mandatory_conditions_pass'] for s in states.values())
    final=states['v3.8']
    case=ROOT/'v3/experiments/v3.8'
    cfg=json.loads((case/'config.json').read_text(encoding='utf-8'))
    for path,digest in cfg['candidate_sha256'].items():
        assert hashlib.sha256((case/path).read_bytes()).hexdigest()==digest,path
    audit=json.loads((case/'implementation_rtl_audit.json').read_text(encoding='utf-8'))
    regression=json.loads((ROOT/'v3/results/v3.8/weight_call_regression/summary.json').read_text(encoding='utf-8'))
    rtl=case/'prj_candidate/sol1/syn/verilog'
    assert hashlib.sha256((rtl/'ResGRU.v').read_bytes()).hexdigest()==audit['source_sha256']==audit['cosim_sha256']==regression['rtl_sha256']
    titles={'v3.1':'FEx inverse 정수/소수부 재배분','v3.2':'보정 seed·정규화 NR 1회','v3.3':'sigmoid multipartite',
            'v3.4':'AreaOptimized_high 합성 설정','v3.5':'recurrent 개별 곱 포화 제거',
            'v3.6':'32채널 단위 FIFO 제어 공유','v3.7':'FIFO 깊이 2→1',
            'v3.8':'진입부 출력 보관 제거·대기 제어 변경'}
    r=final['resources'];t=final['timing'];q=final['hls_out.txt']
    summary=['# 현서 v3 최종 작업 정리','', '2026-11-16. 현재 최종 채택본: **v3.8**. 실제 배치·배선 완료 결과를 기준으로 작성했다.','',
        '## 최종 구현과 검증','',
        f'- LUT **{r["LUT"]:,.0f}**, FF **{r["FF"]:,.0f}**, DSP **{r["DSP"]:,.0f}**, BRAM_18K **0**.',
        f'- II=2, 구현 비교 주기 **{t["period_ns"]:.3f} ns**, WNS **{t["wns_ns"]:+.3f} ns**, WHS **{t["whs_ns"]:+.3f} ns**. 15 ns setup/hold 통과, 배선 오류·미배선 0.',
        f'- PA NMSE **{q["nmse_db"]:.6f} dB**, ACPR L/R **{q["acpr_l_dbc"]:.6f} / {q["acpr_r_dbc"]:.6f} dBc**.',
        '- 기본 7,680샘플 부모·독립 정수 참조·C·수정 RTL 비교 통과. PA 지표는 v3.7과 동일.',
        '- RTL 호출 지연 145클록, 호출 간격 134클록, 전체 실행 16,091클록으로 부모와 동일.',
        '- 호출마다 모든 가중치·bias 계열과 hidden state 초기화 패턴을 바꾼 추가 24호출·1,536샘플 회귀: C/RTL 불일치 0.',
        '- 진입부 단위 검증: 호출별 입력 변경, 동기 RAM 모델, 임의 terminal 대기, 대기 중 reset을 포함한 부모/후보 비교 통과.',
        '- 보드 실측과 전력은 미측정. 처리율은 호출 오버헤드를 제외한 정상상태 환산값이다.','',
        '## 채택 이력','', '| 버전 | 변경 | LUT | FF | DSP | 주기(ns) |', '|---|---|---:|---:|---:|---:|',
        '| v3 기준 원본 | sehyeon v2 final 도입 | 41,387 | 41,088 | 362 | 14.907 |']
    for v,s in states.items():
        a=s['resources'];b=s['timing']
        summary.append(f'| {v} | {titles[v]} | {a["LUT"]:,.0f} | {a["FF"]:,.0f} | {a["DSP"]:,.0f} | {b["period_ns"]:.3f} |')
    summary += ['',f'v3 기준 원본 대비 LUT **{(1-r["LUT"]/41387)*100:.2f}%**, FF **{(1-r["FF"]/41088)*100:.2f}%**, DSP **{(1-r["DSP"]/362)*100:.2f}%** 감소했다. 단계별 수치 변경은 golden float와 bit-exact라는 뜻이 아니며 각 단계의 결과 문서에서 비교 대상을 확인한다.','',
        '## v3.6~v3.8의 의미','',
        '- v3.6: 채널별 데이터 공간과 깊이 2를 유지하고 FIFO 제어를 공유했다.',
        '- v3.7: FIFO 저장 용량과 full/empty 제어를 깊이 1로 바꿨다.',
        '- v3.8: FIFO 앞의 출력 보관 레지스터를 생략하고 생산자를 terminal state에서 대기시킨다. FIFO 깊이 1은 유지한다. 다른 호출의 값이 담길 수 있는 두 저장소를 단순히 동일 데이터로 간주해 삭제한 기법은 아니다.',
        '- v3.8은 임의의 호출 중첩에서 기존 회로와 모든 클럭이 같다는 증명이 아니라, 명시한 검증 조건에서 출력·처리 시간이 유지된 결과다.','',
        '## 현재 LUT·FF 구성','', '| 구역 | LUT | FF | FF 비중 |', '|---|---:|---:|---:|',
        '| 샘플 연산부 | 22,384 | 10,951 | 52.64% |','| FIFO 데이터 저장부 | 0 | 8,386 | 40.31% |',
        '| 진입부 | 499 | 829 | 3.98% |','| 최상위 자체 로직 | 0 | 600 | 2.88% |','| 공유 FIFO 제어부 | 10 | 38 | 0.18% |',
        '| 전체 | 22,893 | 20,804 | 100% |','',
        '연산부는 LUT의 97.78%를 차지한다. 전체 LUT에는 logic LUT 18,039개와 SRL 4,854개가 포함된다. SRL을 FF에 더하지 않는다. 상세 breakdown은 계층 합계 보정까지 명시했으며 상위/하위 모듈을 중복 합산하지 않는다.',
        'v3.7 대비 진입부 FF -8,372개, 연산부 FF +198개로 순감소 -8,174개다. FIFO payload FF 8,386개는 유지됐다.','',
        '## 읽는 순서','',
        '1. [최종 결과](../results/v3.8/RESULTS.md)',
        '2. [최종 변경 설명](v3.8_fifo_entry_fusion.md)',
        '3. [LUT·FF breakdown](../results/v3.8/AREA_BREAKDOWN.md)',
        '4. [전체 PPA 이력](ppa_history_template.md)',
        '5. [논문·기법 적용 범위](PAPER_CANDIDATES.md)',
        '6. [v1부터의 채택 이력](v1기반_채택변경_이력.md)','',
        '## 후속 검토','',
        '연산부 LUT가 주 분석 대상이다. 포화·반올림 변환, DSP 주변 논리, 범위 기반 폭 정리, 선택적 연산 공유는 분석 후보이며 이 패키지의 채택 변경에 추가로 적용된 결과는 아니다.','']
    summary_path=ROOT/'v3/docs/FINAL_HYEONSEO_SUMMARY.md'
    summary_path.write_text('\n'.join(summary),encoding='utf-8')
    entries={}
    for file in sorted((ROOT/'v3').rglob('*')):
        rel=file.relative_to(ROOT)
        if file.is_file() and not excluded(rel): entries[rel.as_posix()]=file
    for folder in ['v2/opendpd_min','v2/tools']:
        for file in sorted((ROOT/folder).rglob('*')):
            rel=file.relative_to(ROOT)
            if file.is_file() and not excluded(rel): entries[rel.as_posix()]=file
    for rel in ['v0/docs/ppa_history_template.md','v1/docs/ppa_history_template.md','v2/docs/ppa_history_template.md','v0/docs/PBL_학생안내_6G_DPD_AI칩설계.md']:
        assert (ROOT/rel).is_file(),rel
        entries[rel]=ROOT/rel
    for file in sorted(rtl.glob('*.v')):
        entries['final_rtl/'+file.name]=file
    template=ROOT/'v3/experiments/v3.5/prj_candidate/sol1/impl/verilog'
    for name in ['run_vivado.tcl','settings.tcl','extraction.tcl','ResGRU.xdc']:
        entries['support/v3.5_vivado_template/'+name]=template/name
    readme='''# v3_fin_hyeonseo

2026-11-16. 기존 v3_hyeonseo.zip의 폴더 구조를 바탕으로 채택본 v3.1~v3.8과 현재 작업 폴더의 최신 정리를 포함했다. **최종 구현은 v3.8**이다.

## 먼저 읽을 문서

- [최종 작업 정리](v3/docs/FINAL_HYEONSEO_SUMMARY.md)
- [최종 PPA·검증 결과](v3/results/v3.8/RESULTS.md)
- [최종 변경과 검증 범위](v3/docs/v3.8_fifo_entry_fusion.md)
- [LUT·FF breakdown](v3/results/v3.8/AREA_BREAKDOWN.md)
- [버전별 결과 목록](v3/results/README.md)
- [누적 PPA 이력](v3/docs/ppa_history_template.md)

## 포함 내용

- `v3/experiments/v3.1~v3.8/`: 채택 버전의 C++/TB, 설정, RTL 후처리, fixture, 해시와 감사 기록.
- `v3/results/`: 실제 C/RTL/독립 참조 출력, PA 지표, HLS·배치배선 보고서와 상태 기록.
- `v3/docs`, `changes`, `baselines`, `reports`: 변경 이력, 코드 diff, 기준 구현과 원래 검증 자료.
- `v3/src`, `tb`: 도입 당시 v3 기준 원본. **최종 v3.8 소스는 `v3/experiments/v3.8/src`다.** `v3/README.md`와 `package_info.json`도 기준 원본의 기존 안내로 보존했다.
- `final_rtl/`: co-simulation 및 실제 구현에 사용한 최종 v3.8 생성 Verilog. v3.8은 C++ 외에 RTL 후처리를 포함하므로 함께 확인한다.
- `v2/opendpd_min`, `v2/tools`: 기존 압축본과 같은 PA 모델·평가 데이터·도구 의존성.
- `v0~v2/docs`: 과거 PPA 이력과 제공 학생 안내.
- `support/v3.5_vivado_template`: 기존 구현 스크립트가 참조하는 Vivado 템플릿 4개.

## 환경과 재실행

Windows, Vitis HLS/Vivado 2024.1, xczu7ev-ffvc1156-2-e, 15ns, HLS uncertainty 1ns, Python 및 numpy/scipy/pandas/torch를 사용했다. 패키지에는 툴 설치 파일·Python 환경을 포함하지 않는다.

보고서 열람과 소스 검토는 바로 가능하다. 재실행 스크립트에는 원래 PC의 Python·Xilinx 경로 및 테스트 fixture 절대경로가 남아 있으므로 새 PC에서는 경로와 관련 해시 설정을 함께 조정해야 한다. 기존 결과는 보존하고 새 작업 복사본에서 재구축한다. v3/experiments의 candidate_sha256은 당시 검증한 바이트를 식별한다.

대용량 `prj_*` 빌드 디렉터리, 캐시, 체크포인트와 생성된 단위 테스트 빌드는 제외했다. `prepare_shared_impl.py`가 사용하는 템플릿은 재실행 작업 복사본의 `v3/experiments/v3.5/prj_candidate/sol1/impl/verilog/` 위치에 `support/v3.5_vivado_template/`의 파일을 복사하면 확보할 수 있다. 이 압축본을 다른 경로에서 전체 재합성해 검증한 이력은 없다.

원본 소스·증거 파일의 바이트는 보존했다. 삭제된 미채택 후보는 포함하지 않았다. `SHA256SUMS.json`은 압축 내부 파일의 SHA-256이며 `ARCHIVE_INFO.json`에 작업 트리·Git 출처를 기록했다. 최종 문서와 이 README는 UTF-8이다.
'''
    entries['README.md']=readme.encode('utf-8')
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    branch=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()
    dirty=subprocess.check_output(['git','status','--short'],cwd=ROOT,text=True,encoding='utf-8')
    info=dict(created_date_kst='2026-11-16',reference_archive=parent_zip.name,
        reference_archive_sha256=hashlib.sha256(parent_zip.read_bytes()).hexdigest(),
        branch=branch,head=head,includes_working_tree=True,working_tree_status=dirty,
        versions=list(states),latest='v3.8',final_resources=r,final_timing=t,
        final_rtl_sha256=audit['source_sha256'],files=len(entries)+2,
        excluded=['prj_*','caches','checkpoints','generated protocol builds','deleted candidates'],
        source_bytes_preserved=True,relocated_full_flow_rerun=False)
    entries['ARCHIVE_INFO.json']=json.dumps(info,ensure_ascii=False,indent=2).encode('utf-8')
    manifest={}
    with zipfile.ZipFile(OUTPUT,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for rel,source in sorted(entries.items()):
            data=source.read_bytes() if isinstance(source,Path) else source
            manifest[rel]=hashlib.sha256(data).hexdigest()
            archive.writestr(NAME+'/'+rel,data)
        archive.writestr(NAME+'/SHA256SUMS.json',json.dumps(manifest,ensure_ascii=False,indent=2).encode('utf-8'))
    with zipfile.ZipFile(OUTPUT) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist())==len(entries)+1
        assert len(archive.namelist())==len(set(archive.namelist()))
        for rel,digest in manifest.items():
            assert hashlib.sha256(archive.read(NAME+'/'+rel)).hexdigest()==digest,rel
        assert not any('/v3.9/' in n or '/prj_' in n for n in archive.namelist())
        assert '\ufffd' not in archive.read(NAME+'/README.md').decode('utf-8')
    digest=hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    (ROOT/(NAME+'.zip.sha256')).write_text(digest+'  '+OUTPUT.name+'\n',encoding='ascii')
    print(json.dumps(dict(archive=str(OUTPUT),files=len(entries)+1,size_MB=round(OUTPUT.stat().st_size/1048576,2),sha256=digest,verified_all_file_hashes=True),indent=2),flush=True)


if __name__=='__main__':
    main()
