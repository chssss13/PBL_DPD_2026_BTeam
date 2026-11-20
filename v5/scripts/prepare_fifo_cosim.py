"""Replay the FIFO and producer changes on isolated v5.1 HLS projects."""
import importlib
import json
from pathlib import Path
import re
import shutil
import sys


ROOT = Path(__file__).resolve().parents[2]


def install_direct_weights(rtl, scope):
    top = (rtl / 'ResGRU.v').read_text()
    path = rtl / 'ResGRU_Loop_LOOP_T_proc.v'
    loop = path.read_text()
    report = []

    def unique(pattern, text):
        matches = re.findall(pattern, text, re.M)
        assert len(matches) == 1, (pattern, matches)
        return matches[0]

    for gate in ('rzn' if scope == 'layer2' else 'zn'):
        for row in range(5):
            for col in range(5):
                weight = f'W_i{gate}_0_{row}_{col}'
                value = unique(r'^assign (\w+) = \$signed\(' + weight + r'\);', top)
                output = unique(r'^\s*(ap_return_\d+) = ' + value + ';', top)
                fifo = unique(r'\.din\(Block_entry_split_proc_U0_' + output + r'\),\s*\.dout\((\w+)\)', top)
                port = unique(r'\.(p_read\w*)\(' + fifo + r'\)', top)
                first = unique(r'^\s*(\w+_reg_\d+) <= ' + port + ';', loop)
                last = unique(r'^\s*(' + first + r'_pp0_iter1_reg) <= ' + first + ';', loop)
                operand = unique(r'^\s*(grp_fu_\d+_p[12] = |\.din[12]\()' + last + r'(?:;|\))', loop)
                # Preserve mux conditions and any other consumers of the register.
                loop = loop.replace(operand + last, operand + port, 1)
                report.append(dict(weight=weight, fifo=fifo, port=port, operand=operand))
    path.write_text(loop)
    (rtl.parents[2] / 'direct_weights.json').write_text(json.dumps(report, indent=2))


def main(scope):
    counts = {'layer2': 511, 'all': 401}
    count = counts[scope]
    run = ROOT / 'v5' / f'prj_shared_{scope}'
    trial = run / 'direct_trial_v2'
    trial.mkdir()
    shutil.copytree(run / 'hls', trial / 'hls')
    rtl = trial / 'hls/sol1/syn/verilog'
    scripts = ROOT / 'v4/result/v4.2/fifo_rtl'
    for source, name in [('fifo_control_base.py', 'fifo_control_base.py'),
                         ('rtl_transform.py', 'depth_one_base.py')]:
        (trial / name).write_text((scripts / source).read_text().replace('566', str(count)))
    fusion = (ROOT / 'v3/scripts/fifo_entry_fusion.py').read_text()
    (trial / 'fusion.py').write_text(fusion.replace('598', str(count)))
    sys.path.insert(0, str(trial))
    importlib.import_module('fusion').transform(rtl, trial / 'audit.json')
    install_direct_weights(rtl, scope)
    golden = run / 'trained100_golden'
    assert golden.is_dir(), golden
    fixture = ROOT / 'v4/result/v4.1'
    (trial / 'cosim.tcl').write_text(f'''open_project {{{(trial / 'hls').as_posix()}}}
set_top ResGRU
add_files {{{(run / 'src/multi_gru.cpp').as_posix()}}} -cflags {{-I{(run / 'src').as_posix()} -DRESET_ARG}}
add_files -tb {{{(fixture / 'tb/tb_resgru.cpp').as_posix()}}} -cflags {{-I{(run / 'src').as_posix()} -I{(fixture / 'src').as_posix()} -DRESET_ARG}}
open_solution sol1
cosim_design -rtl verilog -tool xsim -argv [list {{{golden.as_posix()}}} 7680 {{{(trial / 'rtl_out.txt').as_posix()}}} 2560]
close_project
exit
''')


if __name__ == '__main__':
    main(sys.argv[1])
