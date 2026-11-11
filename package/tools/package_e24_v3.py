"""Build the self-contained v3_daeyeon distribution from the verified E24 snapshot."""
from pathlib import Path
import hashlib
import json
import shutil

REPO = Path(__file__).resolve().parents[2]
E24 = REPO / 'package/results/E24_sehyeon_stable_coefficients'
DEST = REPO / 'exports/v3_daeyeon'
if DEST.exists():
    raise RuntimeError(f'Refusing to overwrite existing distribution: {DEST}')
DEST.mkdir(parents=True)
for name in ['src_snapshot', 'scripts', 'reference']:
    shutil.copytree(E24/name, DEST/name, ignore=shutil.ignore_patterns('__pycache__'))
shutil.copytree(REPO/'runs/sehyeon_final/golden', DEST/'golden')
for name in ['tb_snapshot.cpp', 'source_hashes.json', 'source_changes.diff']:
    shutil.copy2(E24/name, DEST/name)
recorded = DEST/'recorded_results'
recorded.mkdir()
for name in ['RESULTS.md', 'evaluation.json', 'csim_out.txt', 'rtl_out.txt']:
    shutil.copy2(E24/name, recorded/name)
shutil.copytree(E24/'reports/postroute', recorded/'reports/postroute')
for name in ['csim_comparison.json', 'rtl_comparison.json', 'ResGRU_cosim.rpt']:
    shutil.copy2(E24/'reports'/name, recorded/'reports'/name)
report = (E24/'RESULTS.md').read_text(encoding='utf-8')
comparison = '## 원본 동작과 E24가 의도한 변경\n' + report.split('## 원본 동작과 E24가 의도한 변경\n',1)[1].split('## v3_daeyeon 배포본',1)[0]
(DEST/'OPERATION_COMPARISON.md').write_text(comparison,encoding='utf-8')
# Recorded report links that are not shipped with this compact distribution.
report = report.replace('(source_changes.diff)','(../source_changes.diff)').replace('- [최종 checkpoint](checkpoints/postroute.dcp)', '- 최종 checkpoint: 재실행으로 생성하며 배포본에는 포함하지 않음')
report += '\n배포 각주: checkpoint는 이 소스 배포본에 포함하지 않습니다. 재실행으로 생성할 수 있습니다.\n'
(recorded/'RESULTS.md').write_text(report,encoding='utf-8')

runner = (E24/'run.py').read_text(encoding='utf-8')
runner = runner.replace('import os\n','import os\nimport sys\n')
runner = runner.replace('REPO = ROOT.parents[2]\nWORK = REPO / "runs/e24"', '''WORK = Path(os.environ.get("E24_WORK_DIR", str(ROOT / "build"))).resolve()
if " " in str(ROOT) or " " in str(WORK):
    raise RuntimeError("Copy v3_daeyeon to a path without spaces, such as C:/PBL_build/v3_daeyeon")
for directory in ["logs", "reports", "checkpoints"]:
    (ROOT / directory).mkdir(exist_ok=True)
os.environ["E24_WORK_DIR"] = str(WORK)
os.environ["PBL_PYTHON"] = sys.executable''')
runner = runner.replace('HLS = "C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat"','HLS = os.environ.get("PBL_HLS", "C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat")')
runner = runner.replace('VIVADO = "C:/Xilinx/Vivado/2024.1/bin/vivado.bat"','VIVADO = os.environ.get("PBL_VIVADO", "C:/Xilinx/Vivado/2024.1/bin/vivado.bat")')
runner = runner.replace('    (ROOT / "RESULTS.md").write_text(md, encoding="utf-8")','    md += "\\n" + (ROOT / "OPERATION_COMPARISON.md").read_text(encoding="utf-8")\n    (ROOT / "RESULTS.md").write_text(md, encoding="utf-8")')
compile(runner,str(DEST/'run.py'),'exec')
(DEST/'run.py').write_text(runner,encoding='utf-8')
(DEST/'scripts/common.tcl').write_text('''set EROOT [file normalize [file join [file dirname [info script]] ..]]
if {![info exists ::env(E24_WORK_DIR)] || ![info exists ::env(PBL_PYTHON)]} {
    error "Run through python run.py or launch_background.py so Python/build paths are configured"
}
set WORK [file normalize $::env(E24_WORK_DIR)]
set PROJECT [file join $WORK prj]
set PYTHON $::env(PBL_PYTHON)
set GOLDEN [file join $EROOT golden]
proc compare_output {name} {
    global EROOT PYTHON
    puts [exec $PYTHON [file join $EROOT scripts verify.py] --output [file join $EROOT ${name}_out.txt] --json [file join $EROOT reports ${name}_comparison.json]]
}
''',encoding='utf-8')
(DEST/'launch_background.py').write_text('''"""Start one detached run; no polling or progress tracker."""
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parent
if " " in str(root):
    raise SystemExit("Copy this folder to a path without spaces before running")
if (root / "build/prj").exists():
    raise SystemExit("A build already exists; use a fresh copy or python run.py --from-stage as documented")
(root / "logs").mkdir(exist_ok=True)
with (root / "logs/run.log").open("xb") as output:
    child = subprocess.Popen([sys.executable, str(root / "run.py")], cwd=root,
        stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_BREAKAWAY_FROM_JOB | subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW,
        close_fds=True)
print(f"Started background E24 worker: {child.pid}")
print(f"Final results: {root / 'RESULTS.md'}")
''',encoding='utf-8')
(DEST/'README.md').write_text('''# v3_daeyeon — E24 재현 소스

원본 sehyeon 최종본(commit 43bbc198f25ec5bd7473a063c510a819efbf400a)에 STABLE 지시문을 적용한 E24입니다. v3는 배포 이름이며 새로 개선된 성능을 뜻하지 않습니다. 원본 모델 파일 13개를 E24 src_snapshot에서 그대로 복사했습니다.

## 실제 측정 결과

| 항목 | 기존 sehyeon | E24 |
|---|---:|---:|
| 시간 루프 II | 2 | 2 |
| WNS(ns) | +0.049 | +0.056 |
| LUT | 41,388 | 41,385 |
| FF | 41,088 | 41,105 |
| DSP | 362 | 362 |
| BRAM/URAM | 0/0 | 0/0 |

C-sim·RTL co-sim 각각 7,680샘플에서 기존 Q12 출력 코드와 일치했습니다. 자원 절감 효과는 사실상 없었습니다. PA NMSE를 새로 평가한 패키지는 아닙니다. 수치는 코어 OOC의 실제 P&R 결과이며 보드 측정이 아닙니다. 재실행 결과는 물리 배치에 따라 달라질 수 있습니다.

**계수 고정 조건:** 모든 진행 중 호출이 끝날 때까지 가중치·bias·PReLU·gating을 변경하지 않습니다. IQ·출력·segment_start·은닉 상태에는 STABLE을 적용하지 않았습니다.

## 포함 파일

- `src_snapshot/`: 실제 구현 모델 소스 13개.
- `tb_snapshot.cpp`: 검증 테스트벤치(Windows co-sim 파일 한도 조정 포함).
- `golden/`: 입력 벡터와 가중치 43개 파일. Python golden을 재생성할 필요가 없습니다.
- `reference/`: 비교할 기존 Python/C 출력과 기준 P&R JSON.
- `scripts/`, `run.py`: C-sim → HLS → Verilog co-sim → IP export → P&R.
- `launch_background.py`: 독립 백그라운드 실행. 진행 추적·폴링·완료 대기 없음.
- `recorded_results/`: 기존 E24 결과표·출력·co-sim 및 최종 타이밍/자원/DRC 보고서. 새 실행 결과와 구분됩니다.
- `OPERATION_COMPARISON.md`: 원본 동작과 의도했던 변경, 실제 결과의 비교.
- `source_hashes.json`: 모델·테스트벤치 무결성 검사. `SHA256SUMS.json`: 배포본 전체 해시.

## 실행 방법 — Windows

Vitis HLS/Vivado 2024.1, Python 3 표준 라이브러리만 필요합니다. 타깃은 xczu7ev-ffvc1156-2-e, 목표 15ns, HLS uncertainty 1ns입니다. Explore opt/place/route와 AggressiveExplore 물리 최적화를 적용합니다.

**Vitis 경로 제한 때문에 바탕화면 보관본을 공백 없는 짧은 경로(예: `C:/PBL_build/v3_daeyeon`)에 복사해서 실행하세요.**

```powershell
Set-Location C:/PBL_build/v3_daeyeon
py scripts/verify.py --package
py launch_background.py
```

Python 실행기가 `py`로 등록되지 않았다면 설치된 `python.exe`의 전체 경로를 사용하세요. 기본 도구 설치 경로는 `C:/Xilinx/Vitis_HLS/2024.1/bin/vitis_hls.bat`, `C:/Xilinx/Vivado/2024.1/bin/vivado.bat`입니다. 다르면 실행 전에 `PBL_HLS`, `PBL_VIVADO` 환경변수를 설정하세요. 빌드 위치 기본값은 배포본 안의 `build/`이며 `E24_WORK_DIR` 환경변수로 변경할 수 있습니다(공백 없는 경로).

백그라운드 실행 후 바로 다른 작업을 할 수 있습니다. 결과는 배포본 최상위 `RESULTS.md`와 `evaluation.json`에 종료 시 저장되며, 기본 도구 로그는 `logs/`에 남습니다. 기존 측정값은 `recorded_results/`에서 보존됩니다. 도구 실패 또는 II/출력 검증 실패 시 후속 단계는 중단됩니다.

이미 생성된 프로젝트는 덮어쓰지 않습니다. 오류 복구는 원인을 해결한 뒤 `py run.py --from-stage cosim` 등으로 필요한 단계부터 명시적으로 재개하세요. 실행 중 중복 시작하지 마세요. 체크포인트·빌드·캐시·도구 로그는 배포하지 않으며 재실행으로 생성합니다.
''',encoding='utf-8')
(DEST/'.gitignore').write_text('/build/\n/logs/\n/checkpoints/\n/reports/\n/.Xil/\n__pycache__/\n*.log\n*.jou\n/RESULTS.md\n/evaluation.json\n/csim_out.txt\n/rtl_out.txt\n',encoding='utf-8')
(DEST/'.gitattributes').write_text('* -text\n',encoding='utf-8')
for p in (DEST/'src_snapshot').iterdir():
    assert p.read_bytes() == (E24/'src_snapshot'/p.name).read_bytes(), p
checksums = {str(p.relative_to(DEST)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(DEST.rglob('*')) if p.is_file()}
(DEST/'SHA256SUMS.json').write_text(json.dumps(checksums,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'package':str(DEST),'files':len(checksums),'bytes':sum(p.stat().st_size for p in DEST.rglob('*') if p.is_file()),'model_byte_match':True},indent=2))
