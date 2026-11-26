"""Compare the routed-design RTL with the fixed-point C-sim output."""

import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CALLS = 120
WORDS_PER_CALL = 128


def main():
    rtl = ROOT / "rtl"
    vectors = ROOT / "test"
    expected = [int(word, 16) for word in (vectors / "expected.hex").read_text().split()]
    if len(expected) != CALLS * WORDS_PER_CALL:
        raise ValueError(f"Expected {CALLS * WORDS_PER_CALL} C-sim output words.")

    with tempfile.TemporaryDirectory() as directory:
        work = Path(directory)
        for file in (vectors / "iq.hex", vectors / "gate.hex", *rtl.glob("*.dat")):
            shutil.copyfile(file, work / file.name)
        subprocess.run(
            ["iverilog", "-g2012", "-s", "probe", "-o", "probe.vvp",
             str(vectors / "probe.v"), *map(str, sorted(rtl.glob("*.v")))],
            cwd=work,
            check=True,
        )
        log = subprocess.check_output(["vvp", "probe.vvp"], cwd=work, text=True)

    lines = log.splitlines()
    writes = [line.split() for line in lines if line.startswith("WRITE ")]
    completed = sum(line.startswith("DONE ") for line in lines)
    if completed != CALLS or len(writes) != len(expected):
        raise ValueError(f"Unexpected simulation length: {completed} calls, {len(writes)} output words.")

    actual = []
    for start in range(0, len(writes), WORDS_PER_CALL):
        block = sorted((int(line[3]), int(line[4]) % 32768)
                       for line in writes[start:start + WORDS_PER_CALL])
        if [address for address, _ in block] != list(range(WORDS_PER_CALL)):
            raise ValueError(f"Missing or repeated output address in call {start // WORDS_PER_CALL + 1}.")
        actual.extend(value for _, value in block)

    differences = sum(value != reference for value, reference in zip(actual, expected))
    if differences:
        raise ValueError(f"{differences} of {len(expected)} output words differ from C-sim.")
    print(f"PASS: {completed} calls, {len(expected) // 2} I/Q pairs, "
          f"{len(expected)} fixed-point words match C-sim.")


if __name__ == "__main__":
    main()
