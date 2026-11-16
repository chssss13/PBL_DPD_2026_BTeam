from pathlib import Path
import sys,os,json,subprocess,shutil
sys.path.insert(0,'C:/PBL/venv/Lib/site-packages')
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
PARENT=ROOT/'v3/package/results/poly_output_recurrent_style_python'
OUT=ROOT/'v3/package/results/poly_output_original15_python'
assert not OUT.exists()
OUT.mkdir()
m={'__name__':'reference'}
exec(compile((PARENT/'reference_model.py').read_text(encoding='utf-8'),'reference','exec'),m)
qd=m['make_q']('15,3'); qw=m['make_q']('14,4'); qwide=m['make_q']('21,6')
w,cfg=m['load_weights'](ROOT/'v2/package/golden/weights')
f=np.loadtxt(PARENT/'intermediates/layer2.txt')
products=f[:,None,:]*qw(w['W_out'])[None,:,:]
b=qd(w['b_out'])
acc=np.zeros(products.shape[:2]); wide=np.zeros_like(acc)
for i in range(5):
    acc=qd(acc+qd(products[:,:,i]))
    wide=qwide(wide+qwide(products[:,:,i]))
y=qd(acc+b); parent=qd(wide+b)
ref=np.loadtxt(PARENT/'poly_parent.txt')
assert np.array_equal(np.rint(parent*4096),np.rint(ref*4096))
np.savetxt(OUT/'poly_output15.txt',y,fmt='%.10f')
np.savetxt(OUT/'poly_output21.txt',parent,fmt='%.10f')
stats=dict(samples=len(f),parent_q12_match=True,changed_q12_components=int(np.count_nonzero(np.rint(y*4096)!=np.rint(parent*4096))),max_abs_change=float(np.max(np.abs(y-parent))))
(OUT/'comparison.json').write_text(json.dumps(stats,indent=2))
(OUT/'settings.json').write_text(json.dumps(dict(change='Polynomial parity FEx retained; Output FC restored to v4.0 Linear<5,2,data_t,weight_t,data_t>: each product and each sequential sum AP_RND/AP_SAT15,3; final bias then15,3',data='15,3',weight='14,4',samples=7680,reset_every=2560,scope='Python output-only evaluation using validated identical upstream features; no HLS or P&R'),indent=2))
shutil.copyfile(__file__,OUT/'runner_snapshot.py')
cmd=[sys.executable,str(ROOT/'v2/package/tools/eval_pa.py'),'--pa','save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt',str(ROOT/'v2/package/golden/vectors/torch_out.txt'),str(ROOT/'v4/result/v4.0/reference/csim_expected.txt'),str(OUT/'poly_output15.txt'),str(OUT/'poly_output21.txt')]
r=subprocess.run(cmd,cwd=ROOT/'v2/package/opendpd_min',env={**os.environ,'PYTHONIOENCODING':'utf-8','PYTHONPATH':'C:/PBL/venv/Lib/site-packages'},capture_output=True,text=True,encoding='utf-8',errors='replace')
(OUT/'pa_comparison.txt').write_text(r.stdout+r.stderr,encoding='utf-8')
print(r.stdout+r.stderr);r.check_returncode();print(json.dumps(stats))
