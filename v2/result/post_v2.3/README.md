# v2.3 이후 타이밍 개선 실험 근거

[과정 및 결과 정리](../../v2.3_이후_실험정리.md)

HLS 보고서, 완료된 P&R 보고서, 정확도 비교와 진단 기록을 선별 보관한다. 전체 프로젝트와 소스 재현 패키지는 아니다. 보고서 안의 절대 경로는 실행 당시 환경이며 GitHub 탐색 링크가 아니다.

## HLS 및 P&R 실험

- [v1_tree_rec17_csynth](v1_tree_rec17_csynth/)
- [v1_tree_rec17_fabric_csynth](v1_tree_rec17_fabric_csynth/)
- [v1_prelu_fabric_csynth](v1_prelu_fabric_csynth/)
- [v1_state_fabric_csynth](v1_state_fabric_csynth/)
- [v1_prelu_state_fabric_csynth](v1_prelu_state_fabric_csynth/)
- [v1_original_prelu_only_csynth](v1_original_prelu_only_csynth/)
- [v1_original_state_only_csynth](v1_original_state_only_csynth/)
- [v1_interp_original_bits_csynth](v1_interp_original_bits_csynth/)
- [v1_interp_narrow_bits_csynth](v1_interp_narrow_bits_csynth/)
- [z10_csynth_comparison/z10_only](z10_csynth_comparison/z10_only/)
- [z10_csynth_comparison/z10_parallel](z10_csynth_comparison/z10_parallel/)

## 정확도·경로 진단

- [Python 정확도 비교](accuracy/)
- [CE 단순화 진단](ce_simplify_v23/README.md)
- [PReLU 경로 비교](prelu_path_reports/)
