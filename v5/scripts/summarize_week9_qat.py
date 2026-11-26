"""Assemble the Week 9 common-test results after all runs finish."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUNS = ROOT / "v5/prj_week9_qat_stride1"
LABELS = {
    "share_layer2": "현서 · 2층 reset 공유",
    "share_all": "현서 · 전층 reset 공유",
    "fastgrnn": "태수 · FastGRNN",
    "input23": "세현 · 2·3층 입력 기반 게이트",
    "input123": "세현 · 전층 입력 기반 게이트",
}


def read(path):
    return json.loads(path.read_text())


def row(label, kind, m, epoch, elapsed):
    return (
        f"| {label} | {kind} | {m['nmse']:.2f} | {m['evm']:.2f} | "
        f"{m['aclr_l']:.2f} | {m['aclr_r']:.2f} | {m['aclr_average']:.2f} | "
        f"{epoch} | {elapsed} |"
    )


def main():
    lines = [
        "# 9주차 공통 QAT 미세조정 비교",
        "",
        "NMSE·EVM은 dB, ACLR은 dBc다. 고정소수점 Python 참조 출력을 같은 DGRU PA 대리모델에 통과시켜 테스트 7,680샘플을 평가했다. 상태는 2,560샘플마다 초기화했다.",
        "",
        "| 구현 | 조건 | NMSE | EVM | ACLR L | ACLR R | 평균 ACLR | 선택 epoch | 실행 시간 |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|",
        "| 기존 GRU | 배포 가중치 FP32 (원본 기록) | −45.52 | −49.42 | −53.59 | −50.43 | −52.01 | 93 | — |",
        row("v4.7", "배포 가중치 + HW 참조", read(ROOT / "v5/prj_week9_qat/original/baseline_test.json"), "—", "—"),
    ]
    for scope, label in LABELS.items():
        base = RUNS / scope
        lines.append(row(label, "배포 가중치에서 초기화 + HW 참조", read(base/"float/baseline_test.json"), "—", "—"))
        for mode, kind in (("float", "FP32 미세조정 + HW 참조"), ("qat", "QAT 미세조정 + HW 참조")):
            folder = base/mode
            report = read(folder/"test.json")
            history = read(folder/"history.json")
            choice = min(history, key=lambda r: r["aclr_average"])
            if choice["epoch"] != report["best_epoch"]:
                raise ValueError(f"Invalid checkpoint selection: {folder}")
            lines.append(row(label, kind, report["test"], f"{choice['epoch']} (lr {choice['lr']:.3g})",
                             f"{report['seconds']:.0f}초"))
    lines += [
        "",
        "## 실행 조건",
        "",
        "- 학습/검증/테스트 23,040/7,680/7,680, frame 50, stride 1, batch 64, seed 4574, 고정 PA, train에서 계산한 target gain, MSE.",
        "- AdamW 학습률 0.00025, weight decay 0.01, grad clip 200. 검증 평균 ACLR 정체 시 학습률 ×0.5, 최대 100 epoch. 20 epoch 이후 최적 기록이 12 epoch 동안 개선되지 않으면 종료.",
        "- 메모에 프레임 간격이 적혀 있지 않아 비중첩 프레임을 택했다. 각 2,560샘플 학습 구간의 마지막 10샘플은 50개 프레임을 만드는 데 쓰이지 않았다.",
        "- FastGRNN의 공유 W·U는 원본 후보 상태 행렬에서 가져왔고, 초기 zeta=1, nu=0을 사용했다. 다른 후보는 원본 계수에서 해당 연산만 바꿨다.",
        "- QAT 순전파는 고정소수점 데이터 경로와 FEx·활성화 테이블을 Python으로 모사하고, 역전파에는 STE를 사용했다. 실제 C-sim·RTL 및 FPGA 실측은 별도다.",
        "",
        "실행 명령의 형식",
        "",
        "```powershell",
        "python v5/scripts/train_week9_qat.py <scope> <float|qat> v5/prj_week9_qat_stride1/<scope>/<mode> --epochs 100 --stride 1",
        "```",
        "",
        "각 실행의 config.json, history.json, best.pt, test.json은 v5/prj_week9_qat 아래에 있다.",
    ]
    output = ROOT / "v5/results/experiments/WEEK9_QAT_COMPARISON.md"
    output.write_bytes(("\n".join(lines)+"\n").encode("utf-8"))
    print(output)


if __name__ == "__main__":
    main()
