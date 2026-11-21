from pathlib import Path
import subprocess, tempfile, shutil
root = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as folder:
    work = Path(folder)
    for f in [*root.glob('*.hex'), *(root/'rtl').glob('*.dat')]:
        shutil.copyfile(f, work/f.name)
    subprocess.run(['iverilog','-g2012','-s','probe','-o','run.vvp',root/'probe.v',*sorted((root/'rtl').glob('*.v'))],cwd=work,check=True)
    lines = subprocess.check_output(['vvp','run.vvp'],cwd=work,text=True).splitlines()
    writes = [line.split() for line in lines if line.startswith('WRITE ')]
    assert sum(line.startswith('DONE ') for line in lines)==120 and len(writes)==15360
    actual = []
    for start in range(0,len(writes),128):
        block = sorted((int(x[3]),int(x[4])) for x in writes[start:start+128])
        assert [a for a,_ in block]==list(range(128))
        actual.extend(v for _,v in block)
    expected = [int(x,16) for x in (root/'expected.hex').read_text().split()]
    assert actual == expected, next((i for i,(a,e) in enumerate(zip(actual,expected)) if a!=e), 'length mismatch')
    print('PASS: 120 calls, 7680 I/Q pairs, 15360 fixed-point words match C-sim.')
