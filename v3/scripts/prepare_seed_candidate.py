"""Build v3.2 from accepted v3.1 using the paper-derived corrected seed."""
import difflib
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from seed_reference import correction_table,inverse_raw

ROOT=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser()
ap.add_argument('--steps',type=int,choices=[1,2],default=1)
ap.add_argument('--seed-bits',type=int,choices=[5,6],default=6)
args=ap.parse_args()
CASE=ROOT/'experiments/v3.2'
PARENT=ROOT/'experiments/v3.1'
assert not CASE.exists(),'Refusing to regenerate an existing candidate'
for folder in ['src','tb']:shutil.copytree(PARENT/folder,CASE/folder)
table=correction_table(args.seed_bits)
assert min(table)>=-8192 and max(table)<8192
header='''#pragma once
#include "ap_fixed.h"
#include "ap_int.h"
namespace seed_rsqrt {
typedef ap_fixed<16,5,AP_RND,AP_SAT> inverse_t;
typedef ap_ufixed<16,1,AP_RND,AP_SAT> normalized_t;
static const ap_int<14> correction[64] = {TABLE};
inline inverse_t evaluate(ap_uint<14> amp2_code) {
#pragma HLS INLINE
#pragma HLS ARRAY_PARTITION variable=correction complete dim=1
    if (amp2_code==0) return inverse_t(0);
    ap_uint<4> msb=0;
    for (int bit=0;bit<14;++bit) {
#pragma HLS UNROLL
        if (amp2_code[bit]) msb=bit;
    }
    ap_uint<16> m_code=ap_uint<16>(amp2_code) << (15-msb);
    ap_uint<6> address=m_code.range(14,9);
    ap_int<19> seed_raw=ap_int<19>(163840)-ap_int<19>(m_code)+ap_int<19>(correction[address]);
    ap_uint<16> seed_code=ap_uint<16>((seed_raw+ap_int<19>(2)) >> 2);
    normalized_t m,y;
    m.range(15,0)=m_code;
    y.range(15,0)=seed_code;
    // One NR step on normalized m; seed is p(m)=5/4-m/4 plus correction.
    y=y*(normalized_t(1.5)-normalized_t(0.5)*m*y*y);
    ap_uint<16> y_code=y.range(15,0);
    ap_uint<3> scale=(ap_uint<5>(13)-msb) >> 1;
    ap_uint<32> product=y_code*ap_uint<16>(46341);
#pragma HLS BIND_OP variable=product op=mul impl=dsp
    ap_uint<32> aligned=msb[0] ? product : ap_uint<32>(ap_uint<32>(y_code) << 16);
    ap_uint<5> right_shift=20-scale;
    ap_uint<33> rounded=ap_uint<33>(aligned)+(ap_uint<33>(1) << (right_shift-1));
    ap_uint<19> code=rounded >> right_shift;
    ap_int<16> clipped=code>32767 ? ap_int<16>(32767) : ap_int<16>(code);
    inverse_t result;
    result.range(15,0)=clipped.range(15,0);
    return result;
}
}
'''.replace('TABLE',','.join(map(str,table)))
header=header.replace('correction[64]',f'correction[{1 << args.seed_bits}]')
header=header.replace('ap_uint<6> address=m_code.range(14,9);',f'ap_uint<{args.seed_bits}> address=m_code.range(14,{15-args.seed_bits});')
if args.steps==2:
    header=header.replace('    y=y*(normalized_t(1.5)-normalized_t(0.5)*m*y*y);','    for(int nr=0;nr<2;++nr) {\n#pragma HLS UNROLL\n        y=y*(normalized_t(1.5)-normalized_t(0.5)*m*y*y);\n    }')
(CASE/'src/seed_rsqrt.h').write_text(header,encoding='utf-8')
p=CASE/'src/linear_layer.h';text=p.read_text(encoding='utf-8')
text='#include "seed_rsqrt.h"\n'+text
a=text.index('    data_T delta = amp2 - data_T(1);');b=text.index('    amp = amp2 * inv_sqrt;',a)
text=text[:a]+'''    typedef seed_rsqrt::inverse_t inverse_t;
    ap_uint<14> amp2_code=amp2.range(13,0);
    inverse_t inv_sqrt=seed_rsqrt::evaluate(amp2_code);

'''+text[b:]
p.write_text(text,encoding='utf-8')
# TB exhaustively compares the 16384 representable nonnegative amp2 codes.
fixture=CASE/'inverse_expected.txt'
fixture.write_text('\n'.join(str(inverse_raw(a,args.steps,args.seed_bits,table)) for a in range(16384))+'\n')
p=CASE/'tb/tb_resgru.cpp';text=p.read_text(encoding='utf-8')
test='''
    std::ifstream inverse_reference("FIXTURE");
    for (unsigned a=0;a<16384;++a) {
        int expected;
        if (!(inverse_reference >> expected)) return 20;
        seed_rsqrt::inverse_t actual=seed_rsqrt::evaluate(ap_uint<14>(a));
        if (actual.to_double()*2048!=expected) {
            std::cerr << "Seed inverse mismatch at " << a << std::endl; return 21;
        }
    }
    std::cout << "Seed inverse full amp2-domain PASS" << std::endl;
'''.replace('FIXTURE',fixture.resolve().as_posix())
text=text.replace('int main(int argc, char** argv) {','int main(int argc, char** argv) {'+test)
p.write_text(text,encoding='utf-8')
parent=json.loads((ROOT/'results/v3.1/state.json').read_text())
cfg=dict(version='v3.2',candidate_id='v3.2',title='Corrected normalized rsqrt seed; NR four to one',parent='Accepted v3.1 inverse 16/5',parent_state_sha256=hashlib.sha256((ROOT/'results/v3.1/state.json').read_bytes()).hexdigest(),clock_ns=15,uncertainty_ns=1,target_ii=2,samples=7680,reset_every=2560,inverse_integer=5,inverse_width=16,reference_script='seed_reference.py',reference_args=['--steps','1','--seed-bits','6'],comparison_output='results/v3.1/csim/hls_out.txt',baseline_resources=parent['resources'],baseline_period_ns=parent['timing']['period_ns'],baseline_wns_ns=parent['timing']['wns_ns'],force_baseline_q12_exact=False,reference_nmse_max_db=-60,min_resource_improvement_fraction=.01,resource_priority=True,resource_reduction_planned=True,paper='https://perso.ens-lyon.fr/jean-michel.muller/EMTAsilomar05.pdf',paper_scope='Section III polynomial-plus-correction seed; fixed-point normalization and NR/de-scaling are our adaptation')
cfg['candidate_sha256']={p.relative_to(CASE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['src','tb'] for p in (CASE/folder).glob('*') if p.is_file()}
cfg.update(title=f'Corrected rsqrt seed {1 << args.seed_bits} entries; NR four to {args.steps}',reference_args=['--steps',str(args.steps),'--seed-bits',str(args.seed_bits)])
cfg['candidate_sha256']['inverse_expected.txt']=hashlib.sha256(fixture.read_bytes()).hexdigest()
(CASE/'config.json').write_text(json.dumps(cfg,indent=2),encoding='utf-8')
diff=[]
for folder in ['src','tb']:
    for p in (CASE/folder).glob('*'):
        old=PARENT/folder/p.name
        diff.extend(difflib.unified_diff(old.read_text(encoding='utf-8').splitlines(True) if old.exists() else [],p.read_text(encoding='utf-8').splitlines(True),fromfile='v3.1/'+folder+'/'+p.name,tofile='v3.2/'+folder+'/'+p.name))
(CASE/'changes.diff').write_text(''.join(diff),encoding='utf-8')
(CASE/'range_audit.json').write_text(json.dumps(dict(seed_entries=1 << args.seed_bits,seed_entry_width=14,normalized_fraction_bits=15,correction_fraction_bits=17,nr_steps=args.steps,inverse_format=[16,5],amp2_domain_codes=16384,zero_rule='inverse=0; features finite',odd_exponent_factor_q16=46341,coefficient_selection='Whole mantissa domain minimax constant residual; no I/Q fitting'),indent=2))
doc=ROOT/'docs/v3.2_corrected_seed.md'
if not doc.exists():
    doc.write_text(f'# v3.2 — corrected rsqrt seed\n\nParent: accepted v3.1, preserved unchanged. Resource-priority candidate with {1 << args.seed_bits} correction entries and {args.steps} normalized NR iteration(s), replacing four iterations.\n\n[Paper: Ercegovac, Muller, Tisserand, Asilomar 2005, Section III](https://perso.ens-lyon.fr/jean-michel.muller/EMTAsilomar05.pdf). Polynomial p(m)=5/4-m/4 plus correction table; fixed-point normalization and de-scaling are our adaptation. No I/Q fitting.\n\nMandatory II=2, routed 15ns, PA thresholds, full integer reference/C/RTL equality. Requires actual resource reduction; accuracy gain alone is insufficient.\n\n[Method and selection](PAPER_CANDIDATES.md) | [Results](../results/batch/SUMMARY.md)\n\nRejected attempts are actually deleted before this ID is reused. v3.1 is never deleted.\n',encoding='utf-8')
print('Prepared v3.2: one normalized NR step, corrected seed, exhaustive inverse fixture.')
