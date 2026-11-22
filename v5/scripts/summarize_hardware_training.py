"""Collect PA metrics measured on the HLS fixed-point testbench output."""
from pathlib import Path
import re


V5 = Path(__file__).resolve().parents[1]
SCOPES = {'original': '기존 GRU', 'layer2': '현서 2층 공유',
          'all': '현서 전 층 공유', 'input23': '세현 2·3층 입력 기반'}


def main():
    lines = ['# 재학습 모델의 고정소수점 PA 평가', '',
             '각 구조의 HLS C-sim 출력 7,680샘플을 같은 PA 평가기에 넣었다.', '',
             '| 후보 | 초기화 | 학습 방식 | NMSE (dB) | EVM (dB) | ACPR L/R (dBc) |',
             '|---|---|---|---:|---:|---|']
    for scope, name in SCOPES.items():
        run = V5 / f'prj_shared_{scope}'
        for origin, label in [('common', '기존 체크포인트'), ('scratch', '초기 학습')]:
            for phase in ('float', 'qat'):
                tag = f'{origin}_{phase}'
                candidates = [run / f'{tag}_retry_pa.txt', run / f'{tag}_pa.txt']
                metrics = None
                for report in candidates:
                    if report.is_file():
                        metrics = re.search(r'(?m)^\S+\.txt\s+7680\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)',
                                            report.read_text(encoding='utf-8-sig'))
                    if metrics:
                        break
                values = '— | — | 평가 대기'
                if metrics:
                    nmse, evm, left, right = metrics.groups()
                    values = f'{nmse} | {evm} | {left} / {right}'
                lines.append(f'| {name} | {label} | {phase} | {values} |')
    (V5 / 'results/v5.1/HARDWARE_TRAINING.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
