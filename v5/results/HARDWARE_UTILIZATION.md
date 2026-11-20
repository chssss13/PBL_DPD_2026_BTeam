# v5.1 하드웨어 자원

두 후보는 v4.2 HLS 소스에 게이트 공유를 적용했다. 대상 FPGA는 `xczu7ev-ffvc1156-2-e`, 목표 주기는 15 ns다.

| 후보 | HLS 추정 LUT | FF | DSP | BRAM_18K | 추정 주기(ns) | LOOP_T II |
|---|---:|---:|---:|---:|---:|---:|
| 2층 공유 | 166,467 | 100,701 | 511 | 14 | 13.976 | 2 |
| 전 층 공유 | 133,970 | 79,841 | 360 | 14 | 13.976 | 2 |

같은 HLS 추정 단계에서 전 층 공유는 2층 공유 대비 LUT 32,497개, FF 20,860개, DSP 151개가 적다. 2층 후보는 층 루프 unroll도 포함한다.

v4.6 기준의 배치·배선 수치는 LUT 21,660, FF 19,171, DSP 347, BRAM 7.5타일이다. v5.1의 HLS 추정 수치와 단계가 달라 직접 개선율을 계산할 수 없다. [v4.6 결과](../../v4/result/v4.6/README.md)

Vivado OOC 합성은 `vivado -mode batch -source v5/report_shared_utilization.tcl -tclargs layer2` 또는 `all`로 수행한다. 두 후보 모두 같은 면적 합성 옵션과 15 ns 클록을 사용하며 보고서는 각 `v5/prj_shared_<scope>/vivado_utilization/`에 생성된다.

## Vivado 2024.1 합성 결과

| 후보 | CLB LUT | CLB 레지스터 | DSP | BRAM 타일 | 보고서 |
|---|---:|---:|---:|---:|---|
| 2층 공유 | 34,228 | 37,243 | 353 | 7.5 | [자원 보고서](reports/layer2_utilization.rpt) |
| 전 층 공유 | 28,027 | 29,173 | 270 | 7.5 | [자원 보고서](reports/all_utilization.rpt) |

같은 합성 단계에서 전 층 공유는 2층 공유 대비 LUT 6,201개, 레지스터 8,070개, DSP 83개가 적다. 대상은 v4.2 기반 HLS 후보 RTL이다. 현재 v4.6 최종 RTL은 별도 경로에서 보관하며, 두 후보의 v4.6 직접 적용과 배치·배선은 미실시다. [v4 RTL 보관 목록](../../v4/RTL_ARCHIVE.md)
