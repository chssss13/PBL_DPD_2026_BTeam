# 과거 v2.5 독립 보존 및 재현

이 폴더는 삭제된 과거 v2.5를 보존한다. 새 v2.5 번호와 혼동하지 않는다.

## 그대로 보존한 항목

- `src`: 당시 소스. V2_ROM=1, V2_TREE=1, V2_ACT_REG=0, V2_GATE=0.
- `tb`, `golden`, `opendpd_min`, `tools`: 전체 7680샘플 검증 입력과 PA 모델/도구.
- `results/verified`: 당시 소스 스냅샷, 로그, C/RTL 출력, Python 참조, PA 및 구현 보고서.
- `artifacts/rtl`: 당시 생성 RTL과 ROM 초기화 데이터.
- `artifacts/checkpoints/ResGRU_routed.dcp`: 실측한 배치배선 회로 자체.
- `prj_original_v2_5`: 원본 HLS 프로젝트. 내부 절대경로가 있어 이 폴더를 그대로 이동 실행하는 방식보다 아래 재구축 스크립트를 사용한다.

## 정확한 활성 개선법

1. direct sigmoid/tanh의 조합식 complete partition과 zero latency 제약을 제거하고
   `BIND_STORAGE type=rom_1p impl=bram latency=1`, `PIPELINE II=1`, INLINE off 적용.
   LUT 값·주소 매핑·DIRECT_LUT_SHIFT=4를 유지한다.
2. MAC의 직렬 포화 누산을 `sums[2*LEN]` 완전 분할 트리로 전환한다.
   `sums[LEN+i]=accum_T(x[i]*w[i])`, i=LEN-1부터 1까지
   `sums[i]=sums[2*i]+sums[2*i+1]`. 각 노드의 기존 accum 형식을 유지한다.
   포화 덧셈 순서가 바뀌므로 보편적 bit-exact를 가정하지 않는다.

## 재구축 조건과 명령

Vitis HLS/Vivado 2024.1, xczu7ev-ffvc1156-2-e, 클록15 ns, uncertainty1 ns,
DSP full register=false, ResGRU/LOOP_T target II2.
data_t=ap_fixed<16,3,AP_RND,AP_SAT>, weight_t=<16,4>, accum_t=<32,12>.
RESET_ARG, FEX_INTERNAL_FIXED=1, FEX_INV_I=8, ACT_LUT=2, DIRECT_LUT_SHIFT=4.
64샘플 호출, reset 간격2560, 전체7680샘플. 레지스터/gate 축소 옵션은 0이다.

`C:/Project/venv_dpd/Scripts/python.exe repro_v2_5/scripts/run_version.py v2.5`

소스 재합성/배치배선은 도구 휴리스틱에 따라 물리 결과가 달라질 수 있다.
동일한 실측 회로는 보존된 routed DCP를 열어 확인한다:

`C:/Xilinx/Vivado/2024.1/bin/vivado.bat -mode batch -source repro_v2_5/scripts/audit_checkpoint.tcl`

## 당시 검증 결과

II2, 전체 C/RTL cosim PASS, Python/C 및 Python/RTL PASS.
PA NMSE -43.67 dB, ACPR -51.82/-48.38 dBc.
post-route14.885 ns, WNS +0.115 ns, WHS +0.019 ns, routing errors0/미배선0.
LUT44990, FF47877, DSP711, BRAM_18K 환산52.
64샘플 call interval134cycle, 15 ns에서 오버헤드 포함31.8408 MSps.
따라서 오버헤드 포함33.3 MSps 요구는 미달이며 별도 과제다.

`SHA256.json`은 보존 자료의 무결성 확인용이다. 새 실행 결과는 `results/v2.5`에 별도 저장한다.
