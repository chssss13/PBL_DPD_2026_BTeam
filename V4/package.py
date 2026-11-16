from pathlib import Path
import hashlib,json,shutil

root=Path(__file__).resolve().parent
workspace=root.parent
case=workspace/'V4_1/experiments/v38_fex_pipeline/direct'
src=case/'sim/verilog'
rtl=root/'rtl'; rtl.mkdir(exist_ok=True)
for p in src.glob('ResGRU*.v'):
    if not p.name.endswith('.autotb.v'): shutil.copy2(p,rtl/p.name)
hls=root/'hls_reference';shutil.copytree(workspace/'v4_h/experiments/v3.8/src',hls,dirs_exist_ok=True)
for kind in ['synth','pnr']:
    dst=root/'reports'/kind; dst.mkdir(parents=True,exist_ok=True)
    for p in (case/kind).glob('*.rpt'):shutil.copy2(p,dst/p.name)
shutil.copy2(workspace/'V4_1/experiments/v38_fex_pipeline/clock.xdc',root/'clock.xdc')
shutil.copy2(workspace/'V4_1/experiments/v38_direct_weight/group_trial.json',root/'direct_weight_manifest.json')
manifest={p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(rtl.glob('*.v'))}
(root/'rtl_sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('RTL files',len(manifest),'top',manifest['rtl/ResGRU.v'],'loop',manifest['rtl/ResGRU_Loop_LOOP_T_proc.v'])
