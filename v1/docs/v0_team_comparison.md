# 팀원 4명 v0 재현 결과 비교

확인일: 2026-10-26. `git fetch origin` 후 원격 브랜치의 업로드된 파일만 확인했다.
로컬 미업로드 결과나 실제 작업 완료 여부를 추정하지 않았다. 브랜치를 checkout하거나 소스를 수정하지 않음.

| 팀원 브랜치 | 확인 커밋 | 결과 위치 |
|---|---|---|
| daeyeon | 1d1d643 | package/results에는 README만 있음 |
| hyeonseo | 3f62f83 | v0/results, v1/results/E00_v0_implementation |
| sehyeon | 0a6a6d9 | result/v0 |
| taesu | 373a998 | package/results/E00_v0_baseline |

## 발표 표의 6단계와 비교

| 단계 | 사진의 기대 결과 | daeyeon | hyeonseo | sehyeon | taesu |
|---|---|---|---|---|---|
| 1. 기준 모델 검증 | Python exact ↔ golden NMSE ≤ −100 dB (약 −138) | 미확인 | **−138.00 dB, 통과** (벡터 재계산) | **−138.00 dB, 통과** (벡터 재계산) | 미확인 |
| 2. C-sim | 오류 없이 완료 | 미확인 | C 출력 7,680×2 확인; C-sim 완료 문구의 별도 로그는 미확인 | C 출력 7,680×2 확인; C-sim 완료 문구의 별도 로그는 미확인 | 비교·평가 스크린샷에 C 출력 7,680샘플 확인; 완료 문구는 미확인 |
| 3. v0 Python 참조 생성 | ref_v0.txt 생성 | 미확인 | 파일 존재, 7,680×2 | 파일 존재, 7,680×2 | compare 결과 스크린샷에서 참조와 7,680샘플 비교 확인; 원시 벡터 미업로드 |
| 4. 기능 검증 | C ↔ v0 Python NMSE 약 −82.66 dB, PASS (상한 −60) | 미확인 | **−82.66 dB, 통과** (벡터 재계산) | **−82.66 dB, PASS** (로그 및 재계산) | **−82.66 dB, PASS** (스크린샷) |
| 5. C 모델 정확도 | PA 통과 NMSE 약 −26.67 dB | 미확인 | **−26.67 dB**, 기대값 재현 | **−26.67 dB**, 기대값 재현 | **−26.67 dB**, 기대값 재현 (스크린샷) |
| 6. 합성·구현 | II=2, LUT 약 46.6k, Post-Route 약 17 ns | 미확인 | **II=2 / LUT 46,646 / 17.129 ns** | **II=2 / LUT 46,646 / 17.129 ns** | **II=2 / LUT 46,646 / 17.129 ns** |

표의 통과는 해당 비교 기준을 뜻한다. v0의 낮은 PA 정확도를 재현한 것은
v1 정확도 목표를 통과했다는 뜻이 아니다. 세 브랜치 모두 구현 타이밍은 15 ns에 미달한다.
C-sim 출력/비교 결과는 있지만 종료 메시지가 없는 경우, `CSim done with 0 errors`를 직접 봤다고 표기하지 않았다.
daeyeon의 미확인은 결과 미업로드를 의미하며 미실행 또는 실패 판정이 아니다.

## PA 정확도와 구현 후 자원 상세

| 항목 | 사진/제공 기준 | hyeonseo | sehyeon | taesu |
|---|---:|---:|---:|---:|
| PA NMSE (dB) | 약 −26.67 | −26.67 | −26.67 | −26.67 |
| PA EVM (dB) | 사진에 없음 | −28.10 | −28.10 | −28.10 |
| ACPR L / R (dBc) | 사진에 없음 | −39.48 / −36.09 | −39.48 / −36.09 | −39.48 / −36.09 |
| II | 2 | 2 | 2 | 2 |
| LUT (구현 후) | 약 46.6k | 46,646 | 46,646 | 46,646 |
| FF | 사진에 없음 | 49,546 | 49,546 | 49,546 |
| DSP | 사진에 없음 | 648 | 648 | 648 |
| BRAM | 사진에 없음 | 0 | 0 | 0 |
| Post-Route (ns) | 약 17 | 17.129 | 17.129 | 17.129 |
| 15 ns 타이밍 | 사진은 약 17 ns | 실패 | 실패 | 실패 |

자원은 HLS 추정치가 아니라 구현 보고서 값을 사용했다.
같은 숫자가 업로드돼 있다는 사실만으로 서로 다른 PC에서 독립 실행했음을 입증할 수는 없다.

## 근거

- hyeonseo: `v0/results/{ref_exact,ref_v0,hls_out}.txt`, `v0/golden/vectors/torch_out.txt`,
  `v0/results/eval_v0.txt`, `v1/results/E00_v0_implementation/export_impl.rpt`,
  `v0/results/impl.log`의 Final II=2.
- sehyeon: `result/v0/data/{ref_exact,ref_v0,hls_out}.txt`, `package/golden/vectors/torch_out.txt`,
  `result/v0/logs/compare.txt`, `logs/accuracy.txt`, `ResGRU_export.rpt`, `Loop_LOOP_T_proc_csynth.rpt`.
  compare/accuracy 로그는 UTF-16로 읽었다.
- taesu: `package/results/E00_v0_baseline/export_impl.rpt`, `ResGRU_csynth.rpt`,
  `스크린샷 2026-10-16 160208.png` (기능 비교), `스크린샷 2026-10-16 160615.png` (PA 정확도).
- daeyeon: 원격 트리 전체 확인. 배포 README/기준 수치만 있어 개인 실행 결과로 인정하지 않음.

벡터 재계산은 모델을 다시 실행한 것이 아니라, 해당 원격 커밋의 저장 파일에 대해
`10*log10(sum((prediction-reference)^2)/sum(reference^2))`를 계산한 것.
hyeonseo/sehyeon 모두 shape=(7680,2)를 확인했고,
exact 비교 −137.99818470160832 dB, C/모사 비교 −82.66390970156846 dB였다.

## 브랜치별 원본 링크

- [daeyeon 결과 폴더](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/1d1d643/package/results)
- [hyeonseo v0 결과](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/3f62f83/v0/results)
- [sehyeon v0 결과](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/0a6a6d9/result/v0)
- [taesu v0 결과](https://github.com/chssss13/PBL_DPD_2026_BTeam/tree/373a998/package/results/E00_v0_baseline)
