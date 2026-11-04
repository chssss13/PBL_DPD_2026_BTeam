# PPA 이력표 — v0

최신화: 2026-11-04. 이 문서는 v0 결과만 기록한다.
동일 팀 PC의 측정값을 사용하며 조교 환경 참고값(16.659 ns)과 구분한다.
Vitis HLS/Vivado2024.1, xczu7ev-ffvc1156-2-e, 클록15ns.
호출 오버헤드는 제외한다. 처리율 = 1000/Post-Route(ns)/II.
전력 미측정. 미측정은 —로 표시한다. BRAM은 BRAM_18K 환산 개수다.

| 버전 | 날짜 | 변경 내용 (실험 ID) | 참조 대비 NMSE | PASS | PA NMSE / ACPR L / R | II | Post-Route (ns) | 처리율 (MSps) | LUT | FF | DSP | BRAM | 비고 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| v0 | 10-15~16 | 원본 C-sim·모사·팀 PC 구현 | −82.66 | C/Python PASS¹ | −26.67 / −39.48 / −36.09 | 2 | 17.129 | 29.19 | 46,646 | 49,546 | 648 | 0 | 정확도·타이밍 실패; 조교 참고값 아님 |

## 판정

II2는 만족하지만 17.129ns로15ns 타이밍 실패, PA 정확도도 실패다.
v0 재현의 C/Python 비교 PASS는 PA 정확도 통과를 의미하지 않는다.
2026-10-27 기존7680샘플 출력으로 비교를 재확인했으며 C-sim 재실행은 아니다.
HLS uncertainty는4.05ns다. 후속 버전의1ns 조건과 동일한 합성 제약 비교가 아니다.

## 근거

- [팀 PC 구현](../../v1/results/E00_v0_implementation/export_impl.rpt)
- [기능 비교](../results/compare_v0.txt), [PA 평가](../results/eval_v0.txt)
- [작업환경](작업환경_가이드.md)

## 목표

NMSE≤−43.48dB, ACPR L/R≤−50.39/−47.83dBc, II≤2, 실제15ns 타이밍 통과.
자원 도전 기준은 팀 PC v0의 LUT46646/FF49546/DSP648이다.
