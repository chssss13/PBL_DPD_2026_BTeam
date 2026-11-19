"""Keep the final handoff focused on v3; workspace originals stay intact."""
import hashlib
import json
from pathlib import Path
import re
import posixpath
import zipfile

ROOT=Path(__file__).resolve().parents[2]
NAME='v3_fin_hyeonseo'
PATH=ROOT/(NAME+'.zip')
TEMP=ROOT/(NAME+'.tmp.zip')
REMOVED={
    'v3/docs/v1_v2_변경요약.md',
    'v3/docs/v1기반_변경과_논문아키텍처_대응.md',
    'v3/docs/v1기반_채택변경_이력.md',
    'v3/docs/작업환경_가이드.md',
    'v3/README.md', # historical baseline/environment guide; root README replaces it
}


def main():
    assert PATH.is_file() and not TEMP.exists()
    with zipfile.ZipFile(PATH) as old:
        entries={name.removeprefix(NAME+'/'):old.read(name) for name in old.namelist() if not name.endswith('/')}
    removed=[]
    for name in list(entries):
        if name.startswith(('v0/','v1/','v2/')) or name in REMOVED:
            removed.append(name)
            del entries[name]
    entries.pop('SHA256SUMS.json')
    info=json.loads(entries.pop('ARCHIVE_INFO.json').decode('utf-8'))
    readme='''# v3_fin_hyeonseo

2026-11-16. **최종 채택본 v3.8**까지의 v3 작업을 정리한 압축본이다. 기존 v3_hyeonseo.zip의 v3 자료 구성을 참고했다.

## 읽는 순서

1. [최종 작업 정리](FINAL_HYEONSEO_SUMMARY.md) — 압축을 풀면 README 옆에 있다.
2. [최종 PPA·검증 결과](v3/results/v3.8/RESULTS.md)
3. [진입부 출력 보관 제거·대기 제어 변경](v3/docs/v3.8_fifo_entry_fusion.md)
4. [최종 LUT·FF breakdown](v3/results/v3.8/AREA_BREAKDOWN.md)
5. [v3 PPA 이력](v3/docs/ppa_history_template.md)
6. [기법·논문 적용 범위](v3/docs/PAPER_CANDIDATES.md)

## 구성

- `v3/experiments/v3.1~v3.8/`: 채택 버전별 소스·테스트벤치·설정·RTL 후처리 및 해시.
- `v3/results/`: C/RTL 출력, 독립 참조·PA 지표, HLS·배치배선 보고서와 상태 기록.
- `v3/docs/`: v3 버전별 변경 설명, 최종 요약, PPA 이력과 breakdown.
- `final_rtl/`: co-simulation 및 실제 구현에 사용한 최종 v3.8 Verilog.
- `v3/src`, `tb`, `golden`, `reference`, `reports`, `baselines`: v3 도입 기준과 비교 근거. 최종 소스는 **`v3/experiments/v3.8/src/`**에 있다.
- `v3/scripts/`: 분석·검증 스크립트.
- `support/v3.5_vivado_template/`: Vivado 구현 실행·설정·클록 제약·보고서 추출 템플릿 4개. 빌드 폴더를 제외하면서 재현 보조 파일만 따로 보관했다. 최종 설계 소스는 아니다. [설명](support/README.md)

v0~v2 폴더, v1/v2 변경 요약·v1 기반 설명, 작업환경 가이드는 제외했다. PA 평가 스크립트가 참조하는 `v2/opendpd_min`과 `v2/tools`도 이번 압축본에서 제외했다. 전체 재실행 시 해당 의존성과 설치 경로 설정은 원래 작업 저장소를 사용한다. 대용량 빌드 프로젝트·캐시·체크포인트는 포함하지 않았다.

루트 `SHA256SUMS.json`은 이 압축본에 실제 포함된 파일 전체의 무결성 목록이다. 하위의 기존 해시 목록은 당시 원본 검증 기록으로 보존했다. 소스·RTL·측정 증거의 바이트는 유지했고, 안내 문서와 PPA 표는 v3 범위에 맞춰 정리했다.
'''
    entries['README.md']=readme.encode('utf-8')
    summary=entries['v3/docs/FINAL_HYEONSEO_SUMMARY.md'].decode('utf-8')
    summary='\n'.join(line for line in summary.splitlines() if 'v1부터의 채택 이력' not in line)+'\n'
    entries['v3/docs/FINAL_HYEONSEO_SUMMARY.md']=summary.encode('utf-8')
    def root_link(match):
        label,target=match.groups()
        if target.startswith(('http:','https:','#','/')):
            return match[0]
        return '['+label+']('+posixpath.normpath(posixpath.join('v3/docs',target))+')'
    entries['FINAL_HYEONSEO_SUMMARY.md']=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',root_link,summary).encode('utf-8')
    entries['support/README.md']='''# support 폴더의 용도

`v3.5_vivado_template/`는 Vivado 구현을 다시 실행할 때 쓰는 보조 템플릿이다.
v3.8 구현에도 사용했던 v3.5의 동일한 구현 흐름 설정을 보존했다.

| 파일 | 역할 |
|---|---|
| run_vivado.tcl | Vivado 프로젝트·IP 연결과 합성·배치배선 실행 |
| settings.tcl | 대상 장치·언어 등 구현 설정 |
| ResGRU.xdc | 클록 등 타이밍 제약 |
| extraction.tcl | 자원·타이밍 등 결과 보고서 추출 |

`v3/scripts/prepare_shared_impl.py`가 기존 빌드 폴더에서 참조하던 파일들이다.
압축본에서 대용량 빌드 폴더를 제외하면서 이 4개만 따로 보관했다.
기존 스크립트로 재구축하려면 작업 복사본의
`v3/experiments/v3.5/prj_candidate/sol1/impl/verilog/`에 복사한다.

현재 최종 C++ 소스는 `v3/experiments/v3.8/src/`, 검증된 최종 Verilog는
`final_rtl/`에 있다. 결과 문서 열람에는 support 파일을 실행할 필요가 없다.
'''.encode('utf-8')
    original=entries['v3/docs/ppa_history_template.md'].decode('utf-8')
    rows=[line for line in original.splitlines() if re.match(r'\| (?:\*\*)?v3(?:\.| |\*)',line)]
    assert len(rows)==9,len(rows)
    history=['# v3 PPA 이력','',
        'v3 도입 기준부터 현재 최종 채택본 v3.8까지의 실제 배치·배선 결과다. 모든 채택본의 LOOP_T II는 2다.','',
        '| 버전 | 날짜 | 변경 내용 | 참조 대비 NMSE | 기능검증 | PA NMSE / ACPR L / R | II | Post-Route (ns) | 처리율 (MSps) | LUT | FF | DSP | BRAM | 비고 |',
        '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|',*rows,'',
        'Vitis HLS/Vivado 2024.1, xczu7ev-ffvc1156-2-e, 구현 목표 15 ns, HLS uncertainty 1 ns다. 모든 HW 수치는 실제 구현 결과다. 처리율은 호출 오버헤드를 제외한 정상상태 환산값이며 보드 실측과 전력은 미측정이다.','',
        '참조 대비 NMSE는 구현과 해당 후보의 독립 정수 참조를 비교한 값이다. −3028.13 dB는 출력 불일치 0일 때 비교 스크립트가 반환하는 수치 하한이며 PA 정확도와 다르다. PA NMSE·ACPR은 제공 PA 모델을 통과한 지표다.','',
        '공식 PA 기준은 NMSE ≤ −43.48 dB, ACPR L/R ≤ −50.39 / −47.83 dBc다. II=2, 실제 15 ns setup/hold 및 배선 검증 통과 여부와 구분해 판단한다.','',
        '[최종 결과](../results/v3.8/RESULTS.md) · [최종 LUT·FF breakdown](../results/v3.8/AREA_BREAKDOWN.md)','']
    entries['v3/docs/ppa_history_template.md']='\n'.join(history).encode('utf-8')
    # Remove links to explicitly omitted guides without rewriting source/evidence.
    for name,data in list(entries.items()):
        if not name.endswith('.md'):
            continue
        text=data.decode('utf-8-sig')
        text=re.sub(r'\[([^\]]+)\]\(([^)]*(?:v1_v2_|v1기반_|작업환경_가이드)[^)]*)\)',r'\1',text)
        entries[name]=text.encode('utf-8')
    entries['v3/scripts/trim_final_archive.py']=Path(__file__).read_bytes()
    info['scope']='v3 only; v0-v2 folders and legacy/environment guides omitted'
    info['removed_from_previous_package']=sorted(set(info.get('removed_from_previous_package',[])+removed))
    info['files']=len(entries)+2
    info.pop('source_bytes_preserved',None)
    info['source_and_evidence_bytes_preserved']=True
    entries['ARCHIVE_INFO.json']=json.dumps(info,ensure_ascii=False,indent=2).encode('utf-8')
    hashes={name:hashlib.sha256(data).hexdigest() for name,data in sorted(entries.items())}
    with zipfile.ZipFile(TEMP,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as new:
        for name,data in sorted(entries.items()):
            new.writestr(NAME+'/'+name,data)
        new.writestr(NAME+'/SHA256SUMS.json',json.dumps(hashes,ensure_ascii=False,indent=2).encode('utf-8'))
    with zipfile.ZipFile(TEMP) as new:
        assert new.testzip() is None
        assert all(not name.startswith(('v0/','v1/','v2/')) and name not in REMOVED for name in hashes)
        assert len(new.namelist())==len(hashes)+1
        for name,digest in hashes.items():
            assert hashlib.sha256(new.read(NAME+'/'+name)).hexdigest()==digest,name
    TEMP.replace(PATH)
    digest=hashlib.sha256(PATH.read_bytes()).hexdigest()
    (ROOT/(NAME+'.zip.sha256')).write_text(digest+'  '+PATH.name+'\n',encoding='ascii')
    print(json.dumps(dict(files=len(hashes)+1,removed=len(removed),size_MB=round(PATH.stat().st_size/1048576,2),verified=True),indent=2))


if __name__=='__main__':
    main()
