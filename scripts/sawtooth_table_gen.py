from pathlib import Path

samples = []
for n in range(2048):
    v = round(-32768 + 65535 * n / 2047)  # Ramp from -32768 to +32767
    samples.append(v & 0xFFFF)           # Encode as 16-bit two's complement

Path("mem/sawtooth_2048x16.mem").write_text(
    "".join(f"{sample:04X}\n" for sample in samples),
    encoding="ascii",
)