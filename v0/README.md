# LW-ResGRU DPD 가속기 — PBL 배포 패키지 (v0)

2026-2학기 PBL "6G 통신을 위한 DPD AI 칩 설계" 학생 배포본입니다. 과제 전체 안내는 `docs/PBL_학생안내_6G_DPD_AI칩설계.md`, 출발점 설계의 알려진 문제는 `docs/v0_알려진문제.md`를 먼저 읽으세요.

## 구성

```
.
├─ README.md               ← 이 파일
├─ docs/
│   ├─ PBL_학생안내_6G_DPD_AI칩설계.md   과제 안내 (목표, 규칙, 로드맵)
│   ├─ v0_알려진문제.md                  v0의 기능 문제 4가지 (증상·측정 손실)
│   ├─ 작업환경_가이드.md                Windows(내 PC) / Linux(서버) 설정, 명령어 대응표, PPA 측정 기준
│   └─ ppa_history_template.md           PPA 이력표 양식
├─ src/                    ← HLS 설계 v0 (논문 LW-ResGRU HLS 원본, config만 H=5, L=3)
│   ├─ config.h              H_SIZE, NUM_LAYERS, TIME_STEP, 고정소수점 타입
│   ├─ multi_gru.cpp/.h      top 함수 ResGRU (FEx → 입력 투영 → PReLU → GRU×3 + 잔차 → 출력)
│   ├─ gru_cell.h            GRU 게이트 계산 (행렬곱, 활성화, 상태 갱신)
│   ├─ linear_layer.h        행렬곱(MAC), Linear, FEx
│   ├─ activations.h         활성화 함수, PReLU (rfnoc-hls-neuralnet 기반, GPL-3.0)
│   ├─ wrapper.cpp           원본 시스템 인터페이스 Res_HW_wrapper (사용·수정은 여러분 판단)
│   └─ (기타 헤더)
├─ tb/tb_resgru.cpp        ← 학습 가중치를 읽어 ResGRU를 실행하는 testbench
├─ scripts/run_resgru.tcl  ← csim / csynth / cosim / impl 빌드 스크립트
├─ golden/                 ← 기준 데이터 (논문 모델, seed 4574)
│   ├─ weights/*.txt         게이트별로 나눈 학습 가중치 (float, 한 줄에 값 하나)
│   ├─ weights/manifest.json 각 가중치의 shape, 최솟값/최댓값
│   └─ vectors/              dpd_in.txt (test 입력 7,680×2), torch_out.txt (PyTorch 출력)
├─ tools/
│   ├─ hw_ref.py             HLS와 같은 순서로 계산하는 Python 참조 모델 + 고정소수점(PTQ) 시뮬레이션
│   ├─ compare_out.py        HLS 출력 vs 참조 → NMSE, 최대 오차, PASS/FAIL
│   └─ eval_pa.py            DPD 출력 → PA 대리모델 → NMSE / EVM / ACPR
├─ opendpd_min/            ← eval_pa.py 실행에 필요한 OpenDPD 최소 구성 (Apache-2.0)
│   └─ datasets/DPA_200MHz, save/…/PA_S_4574_…pt (PA 대리모델) 등
└─ results/                ← 출력이 저장되는 곳 (실험별로 results/<실험ID>/에 정리)
```

## 환경 — Windows(내 PC) 또는 Linux(Ubuntu PC·Linux 서버)

두 방식 중 하나로 진행합니다. 설치·접속 방법, 명령어 대응표, PPA 측정 기준은 **`docs/작업환경_가이드.md`를 먼저 읽으세요.**

| | A. 내 PC (Windows) | B. Linux (Ubuntu PC / Linux 서버) |
|---|---|---|
| 툴 | Vitis HLS / Vivado 2024.1 직접 설치 | 직접 설치 (서버에 이미 있으면 그대로) |
| 시작 | "Vitis HLS 2024.1 Command Prompt" | `bash` → `source <설치경로>/Vitis_HLS/2024.1/settings64.sh` (Vivado도 같은 방식) |
| 명령 | PowerShell (`$env:STEPS="csynth impl"; …`) | 아래 명령 그대로 (bash) |

- 툴 버전은 **2024.1**로 통일합니다. 디바이스 `xczu7ev-ffvc1156-2-e`, 클록 15 ns.
- macOS에는 툴이 설치되지 않습니다 → 팀원의 Windows PC나 Linux 환경을 쓰세요. (연구실 서버 계정은 제공하지 않습니다.)
- 패키지는 **한글·공백이 없는 경로**에 두세요.
- Python: `hw_ref.py`, `compare_out.py`는 numpy만, `eval_pa.py`는 torch(CPU)가 필요합니다. **이 과제용 가상환경(venv)을 만들어 쓰세요** — 만드는 법과 이유는 `docs/작업환경_가이드.md` §A-3. 새 창을 열 때마다 venv를 활성화해야 합니다.

## 처음 30분: v0를 직접 돌려 보기

**1. Python 참조 모델이 PyTorch와 같은지 확인** (−100 dB 이하면 정상)

```bash
python tools/hw_ref.py --golden golden --out results/ref_exact.txt --ref golden/vectors/torch_out.txt
```

**2. v0 HLS C-sim** (약 10초)

```bash
vitis_hls -f scripts/run_resgru.tcl
```

**3. v0와 같은 동작을 Python으로 재현해 비교**

```bash
python tools/hw_ref.py --golden golden --fxp hls --act hard --fex nr_fx --reset_every 64 --out results/ref_v0.txt
```

```bash
python tools/compare_out.py results/hls_out.txt results/ref_v0.txt --nmse_max -60
```

**4. 정확도 측정 (PA 대리모델 통과)**

```bash
cd opendpd_min && python ../tools/eval_pa.py --pa save/DPA_200MHz/train_pa/PA_S_4574_M_DGRU_H_8_F_50_P_486_D_0.pt ../golden/vectors/torch_out.txt ../results/hls_out.txt; cd ..
```

v0의 NMSE가 약 **−26.7 dB**로, 목표(−43.48 dB)에 크게 못 미치는 것을 확인할 수 있습니다. 이것을 고치는 것이 첫 과제(v1)입니다.

**5. 합성·구현** (30~60분)

Linux (서버는 접속이 끊겨도 계속 돌도록 nohup):

```bash
STEPS="csynth impl" nohup vitis_hls -f scripts/run_resgru.tcl > results/impl.log 2>&1 &
```

Windows PowerShell (PC가 절전·재부팅되지 않게, 창을 닫지 말 것):

```powershell
$env:STEPS="csynth impl"; vitis_hls -f scripts/run_resgru.tcl > results/impl.log 2>&1
```

- II: `prj_resgru/sol1/.autopilot/db/autopilot.flow.log`에서 `Pipelining result`
- 자원·타이밍: `prj_resgru/sol1/impl/report/verilog/export_impl.rpt`

## 도구 요약

### `tools/hw_ref.py` — Python 참조 모델

| 옵션 | 의미 |
|---|---|
| `--act exact\|hard` | 정확한 sigmoid/tanh, 또는 v0의 hard sigmoid/tanh |
| `--fex exact\|nr\|nr_fx` | 정확한 FEx, v0 FEx 식(float), v0 FEx 식 + `ap_fixed<16,2>` 포화 |
| `--reset_every N` | N샘플마다 은닉 상태 리셋 (기본 2560 = golden 조건, v0는 64) |
| `--data_t / --weight_t / --accum_t W,I` | 고정소수점 타입 (`ap_fixed<W,I,AP_RND,AP_SAT>`). HLS 소스와 같은 위치에서 반올림·포화 |
| `--fxp hls` | v0 타입 일괄 지정 (16,2 / 16,2 / 18,3) |
| `--dump DIR` | 중간 결과(fex, prelu, layerN) 저장 → 범위 분석, 블록별 디버깅 |

- 여러분의 HW가 새 근사(예: 다른 활성화 구현)를 쓰면, `hw_ref.py`에도 **같은 계산**을 추가해 참조를 만드세요. 그래야 HLS 결과를 bit 단위로 검증할 수 있습니다.
- `--data_t` 등으로 비트폭을 바꿔 가며 `eval_pa.py`로 재면, **재학습 없이** 비트폭별 정확도(PTQ)를 확인할 수 있습니다.

### `tools/compare_out.py` — 기능 검증

마지막 줄이 `PASS` 또는 `FAIL`이라 regression 스크립트에서 `tail -1`로 판정할 수 있습니다. `--bitexact`를 주면 완전 일치를 요구합니다.

### `tools/eval_pa.py` — 정확도 지표

- 반드시 **2,560 샘플 구간 단위**로 계산합니다 (OpenDPD 학습 로그와 같은 방식). 7,680 샘플을 한 번에 재면 ACPR이 15 dB 가량 다르게 나옵니다.
- 여러 파일을 한 번에 주면 첫 파일 대비 Δ를 보여 줍니다.

## 기준 수치

| | NMSE | EVM | ACPR L / R |
|---|---|---|---|
| DPD 없음 | −11.07 | −11.71 | −31.99 / −30.00 |
| v0 (논문 HLS 원본) | −26.67 | −28.10 | −39.48 / −36.09 |
| **정확도 목표 (논문 Table I)** | **≤ −43.48** | | **≤ −50.39 / −47.83** |
| 학습 모델 (seed 4574, float) | −45.52 | −49.42 | −53.59 / −50.43 |

| v0 HW (ResGRU 코어, 2024.1, 15 ns) | II | LUT | FF | DSP | BRAM | 배치·배선 후 |
|---|---|---|---|---|---|---|
| v0 | 2 | 46,544 | 49,551 | 648 | 0 | 16.659 ns (타이밍 미달) |

> 위 HW 수치는 조교 환경(연구실 서버, Vivado 2024.1)의 참고값입니다. 환경에 따라 조금 다를 수 있으니 **팀의 PPA 측정 환경을 하나로 정하고, 그 환경에서 v0를 한 번 구현해 PPA 이력표의 v0 행으로 기록**하세요. 개선률은 같은 환경에서 잰 값끼리 비교합니다. 정확도(NMSE·ACPR)는 Python 계산이라 어디서나 같습니다.

처리율 목표는 **논문이 주장한 II=2 @ 66 MHz (33.3 MSps)** 입니다. 자세한 목표는 안내문 §6을 보세요.

## 라이선스

- `opendpd_min/`: OpenDPD (TU Delft), Apache-2.0 — `opendpd_min/LICENSE`
- `src/activations.h`, `src/nnet_common.h`: rfnoc-hls-neuralnet, GPL-3.0-or-later (파일 머리말 참고)
- `src/fxp_sqrt.h`: AMD, Apache-2.0
- 이 패키지나 작업 결과를 외부에 공개·공유할 계획이면 조교와 먼저 상의하세요.
