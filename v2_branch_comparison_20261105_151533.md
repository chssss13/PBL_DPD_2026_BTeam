# 브랜치별 v2 진행 상황 비교

수집 시각: 2026-11-05T15:15:33.195349+09:00
압축파일: `v2_branch_files_20261105_151533.zip`
ZIP SHA256: `177187de4a7509713939f00b36f0970658a91f33b7236f986e678bf882c788dd`

## 압축파일 범위

ZIP에는 각 원격 브랜치에 실제 올라온 v2 관련 파일만 브랜치별로 담았다.
별도 공유 ZIP 복사본, 로컬 미커밋 비교 자료, 생성한 STATUS/README/JSON은 넣지 않았다.
이 MD가 유일한 종합 비교 자료이며 ZIP 밖에 둔다. main은 제외했다.
원격의 v2/result/final 안에 포함된 sehyeon 공유 구현은 실제 브랜치 파일이므로 그대로 포함한다.
이것은 따로 전달받은 ZIP을 중복 삽입한 것이 아니다.

| 폴더 | 포함 범위 |
|---|---|
| hyeonseo/v2/ | 해당 원격 커밋의 v2 전체:소스·TB·도구·입력·모델·스크립트·문서·결과 |
| sehyeon/v2/ | 해당 원격 커밋의 v2 전체:실험 이력·package·result·현재 final 포함 |
| daeyeon/package/ | v2 단계의 E20 전체 결과·고정 소스·TB와 재현 스크립트·입력·PA 환경·검증 도구 |
| taesu/ | 원격에 v2 관련 결과가 없어 빈 폴더로 표시; v0 자료를 v2로 대신 넣지 않음 |

원래 저장소의 경로 구조와 Git blob 바이트를 보존했다. hyeonseo/sehyeon의 v2/ 파일 누락이 없음을 확인했다.
daeyeon E20은 실제 폴더명이 v2가 아니므로 해당 실험과 실행 의존성을 명시적으로 포함했다.
v0/v1/v3 및 과거 독립 repro_v2_5 보존본은 이번 범위가 아니다.
버전 문서의 과거 기준 링크가 그 범위 밖 파일을 가리키는 경우 원격 저장소를 참고한다.

## 최신 커밋과 파일 수

| 브랜치 | 고정한 원격 커밋 | 커밋 날짜 | 포함 파일 |
|---|---|---|---:|
| hyeonseo | `e34aa860ff7744f60990f2ef2b1c8765efb16628` | 2026-11-04T22:32:05+09:00 | 273 |
| sehyeon | `43bbc198f25ec5bd7473a063c510a819efbf400a` | 2026-11-04T22:47:51+09:00 | 474 |
| daeyeon | `162d9f92e0da5aa8e3a9dff7cd0baf4308605a8a` | 2026-11-05T00:39:22+09:00 | 151 |
| taesu | `b4a481643e4dfb0758a2cf0a915bcd008cd58f6a` | 2026-10-26T20:02:50+09:00 | 0 |

## 핵심 결과

| 항목 | hyeonseo | sehyeon | daeyeon | taesu |
|---|---:|---:|---:|---|
| 현재 후보 | v2.2 | final/state_nosat | E20_input_precompute | v2 원격 자료 없음 |
| PA NMSE dB | −43.67 | −44.97 | −45.62 | — |
| ACPR L/R dBc | −51.82/−48.38 | −53.35/−50.08 | −53.54/−50.38 | — |
| LOOP_T II | 2 | 2 | 2 | — |
| 구현 후 비교 주기 ns | 14.885 | 14.907 | 15.844 | — |
| WNS ns | +0.115 | +0.093 | −0.844 | — |
| WHS ns | +0.019 | +0.037 | +0.036 | — |
| 15ns 판정 | PASS | PASS | FAIL | 미판정 |
| 실제 LUT | 44,990 | 41,387 | 59,878 | — |
| 실제 FF | 47,877 | 41,088 | 52,017 | — |
| 실제 DSP | 711 | 362 | 722 | — |
| BRAM_18K 환산 | 52 | 0 | 0 | — |
| C-sim 입력 | 7,680 | 7,680 | 7,680 | — |
| RTL co-sim | 7,680샘플 PASS | 미수행 | 2,624샘플 PASS | v2 미수행 |

호출 오버헤드는 판정에서 제외한다. II2·15ns의 정상상태는33.333MSps이며,
실제로15ns를 만족한 경우에만 이 클록에서 달성으로 판단한다.
위 주기는 구현 보고서 또는15−WNS 환산값으로,보드에서 측정한 Fmax가 아니다.
전력·보드 실측은 이 표에 포함하지 않는다. BRAM52는36K 타일26개의18K 환산이다.

## 설계 변경의 차이

- **hyeonseo:** data16/3·weight16/4·accum32/12,BRAM 직접 조회 activation과 균형 MAC.
  정확도·II2·실제15ns·전체 RTL 검증 완료. v2.3/v2.4 및 v3.1은 폐기했다.
- **sehyeon:** data15/3·weight14/4·기본accum18/3,256구간 보간 및 NR FEx.
  최종본은 GRU 누산21/6,곱셈의 게이트·항·행별 분리,z unsigned12,
  상태 결과 최종 포화 생략을 누적했다. 주요 자원은 가장 적지만 RTL 검증은 남아 있다.
- **daeyeon:** data16/2·weight16/4·accum18/3·gate20/5,자기 층 이전 상태와 독립적인
  입력 MAC·bias를 사전 계산한다. Vivado 임계 net 복제와 Explore 물리 최적화도 적용했다.
  정확도는 가장 낮은 NMSE지만15ns에는0.844ns 부족하다. 고정 구현 입력은 E20/src_snapshot이다.
- **taesu:** 현재 원격은 v0 재현까지만 확인돼 v2 수치를 만들지 않았다.

두 타이밍 통과본만 보면 sehyeon은 hyeonseo 대비 LUT8.01%,FF14.18%,DSP49.09%가 적고,
PA NMSE가1.30dB 낮다. hyeonseo는 전체 RTL 검증을 마쳤다는 차이가 있다.
비트폭·활성화·FEx·구현 옵션이 다르므로 차이를 기법 하나의 효과로 단정하지 않는다.
HLS uncertainty도 hyeonseo/sehyeon은1ns,daeyeon E20은4.05ns로 다르다.

## ZIP 안에서 먼저 볼 파일

- hyeonseo/v2/docs/experiment_history.md
- hyeonseo/v2/docs/v2.2_balanced_mac.md
- hyeonseo/v2/results/v2.2/state.json
- sehyeon/v2/README.md
- sehyeon/v2/result/final/README.md
- sehyeon/v2/result/final/reports/결과요약.md
- daeyeon/package/results/E20_input_precompute/README.md
- daeyeon/package/results/E20_input_precompute/REPRODUCE.md
- daeyeon/package/results/E20_input_precompute/postroute/implementation_results.json

원본 문서의 절대 경로는 실행 당시 기록이다. 재실행 시 각 브랜치의 재현 문서를 따른다.
이번 묶음 생성에서 브랜치 전환·병합이나 새 HLS·P&R 실험은 수행하지 않았다.

검증: ZIP CRC와 모든 포함 파일898개의 SHA256을 원격 Git blob 원본과 대조했다.
