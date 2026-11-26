"""Summarize scratch training followed by QAT for each DPD architecture."""
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def main():
    lines = ['# DPD 초기 학습 비교', '',
             'DPD를 새로 초기화하고 PA는 고정했다. 네 구조 모두 float32 100 epoch 후 검증 최적 체크포인트에서 파라미터 QAT 100 epoch를 수행했다. QAT는 가중치 14/4 및 bias 15/3을 반영한다.', '',
             '| 구조 | 단계 | 선택 epoch | NMSE (dB) | EVM (dB) | ACPR L/R (dBc) |',
             '|---|---|---:|---:|---:|---|']
    for scope in ('layer2', 'all', 'input23', 'original'):
        for phase in ('float', 'qat'):
            run = ROOT / 'build/v5_scratch100' / scope / phase
            metrics = (run / 'evaluation.txt').read_text(encoding='utf-8').splitlines()
            row, = [line.split() for line in metrics if line.startswith('candidate.txt')]
            summary = json.loads((run / 'validation.json').read_text())
            assert len(summary['validation_nmse_db']) == 101 and row[1] == '7680'
            lines.append(f'| {scope} | {phase} | {summary["best_epoch"]} | {row[2]} | {row[3]} | {row[4]} / {row[5]} |')
    (ROOT / 'v5/results/experiments/SCRATCH_TRAINING.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
