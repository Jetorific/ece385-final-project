import math
from pathlib import Path

samples = []
for n in range(2048):
    v = round(32767.5 * math.sin(2 * math.pi * n / 2048) - 0.5)  # -32768..32767
    samples.append(v & 0xFFFF)  # convert to unsigned

Path("mem/sine_2048x16.mem").write_text(
    "".join(f"{sample:04X}\n" for sample in samples),
    encoding="ascii",
)