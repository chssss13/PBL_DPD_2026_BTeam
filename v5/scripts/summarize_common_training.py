"""Collect the same-condition, 100-epoch PA test results."""
import json
from pathlib import Path
import sys


def main(folder):
    names = {'layer2': '현서 2층 공유', 'all': '현서 전 층 공유',
             'input23': '세현 2·3층 입력 기반', 'original': '대연 기존 GRU 구조'}
    rows = []
    baseline = None
    for scope, name in names.items():
        run = folder / scope
        summary = json.loads((run / 'validation.json').read_text())
        assert len(summary['validation_nmse_db']) == 101, scope
        scores = {}
        for line in (run / 'evaluation.txt').read_text(encoding='utf-8').splitlines():
            fields = line.split()
            if fields and fields[0] in ('baseline.txt', 'candidate.txt'):
                assert fields[1] == '7680', fields
                scores[fields[0]] = fields[2:6]
        if baseline is None:
            baseline = scores['baseline.txt']
        assert baseline == scores['baseline.txt'], scope
        rows.append([name, str(summary['best_epoch']), *scores['candidate.txt']])
    lines = ['# 동일 조건 100 epoch 재학습 비교', '',
             '기존 float32 DPD 체크포인트에서 시작했다. PA 고정, DPD 전체 float32 미세조정, Adam 0.00025, seed 4574, 조기 종료 없이 100 epoch를 네 구조에 공통으로 적용했다.', '',
             '테스트 7,680샘플에서 float32 DPD 출력을 동일 PA 모델로 평가했다. 세현 행은 입력 기반 게이트 구조를 비교하며 고정소수점 하드웨어의 반올림·파이프라인 수정은 평가 범위에 포함되지 않는다.', '',
             '| 모델 | 선택 epoch | NMSE (dB) | EVM (dB) | ACPR L (dBc) | ACPR R (dBc) |',
             '|---|---:|---:|---:|---:|---:|']
    for row in [['공통 초기 체크포인트', '—', *baseline], *rows]:
        lines.append('| ' + ' | '.join(row) + ' |')
    qat_runs = [('daeyeon_qat', names['original']),
                *((f'{scope}_qat', names[scope]) for scope in ('layer2', 'all', 'input23'))]
    available_qat = [(folder / scope, name) for scope, name in qat_runs
                     if (folder / scope / 'validation.json').is_file()]
    if available_qat:
        lines.extend(['', '## 하드웨어 파라미터 형식을 적용한 QAT', '',
                      '동일 초기 체크포인트 및 100 epoch 설정을 사용했다. 순전파에 가중치 14/4와 bias 15/3을 적용하고 PA를 고정했다. PA 평가는 양자화한 파라미터와 float 연산을 사용했다. E42 고유 학습 코드와 FPGA 고정소수점 데이터 경로는 재현 범위 밖이다.', '',
                      '| 모델 | 선택 epoch | NMSE (dB) | EVM (dB) | ACPR L (dBc) | ACPR R (dBc) |',
                      '|---|---:|---:|---:|---:|---:|'])
        qat_baseline = None
        for qat, name in available_qat:
            summary = json.loads((qat / 'validation.json').read_text())
            assert summary['parameter_qat'] and len(summary['validation_nmse_db']) == 101
            for line in (qat / 'evaluation.txt').read_text(encoding='utf-8').splitlines():
                fields = line.split()
                if not fields or fields[0] not in ('baseline.txt', 'candidate.txt'):
                    continue
                assert fields[1] == '7680'
                values = fields[2:6]
                if fields[0] == 'baseline.txt':
                    if qat_baseline is not None:
                        assert values == qat_baseline
                        continue
                    qat_baseline = values
                    row = ['양자화 초기 체크포인트', '—', *values]
                else:
                    row = [name, str(summary['best_epoch']), *values]
                lines.append('| ' + ' | '.join(row) + ' |')
    destination = Path(__file__).resolve().parents[1] / 'results/v5.1/COMMON_TRAINING.md'
    destination.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(destination)


if __name__ == '__main__':
    main(Path(sys.argv[1]))
