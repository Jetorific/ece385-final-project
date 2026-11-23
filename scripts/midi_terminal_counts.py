from math import floor
from pathlib import Path

CLK_HZ = 100_000_000
COUNT_BITS = 23

counts = []
for note in range(128):
    hz = 440.0 * 2.0 ** ((note - 69) / 12.0)
    half_period_ticks = floor(CLK_HZ / (2.0 * hz) + 0.5)
    terminal_count = half_period_ticks - 1

    assert 0 <= terminal_count < (1 << COUNT_BITS), (note, terminal_count)
    counts.append(terminal_count)

assert counts[69] == 113_635  # A4: 440 Hz

Path("mem/midi_terminal_counts.mem").write_text(
    "".join(f"{count:06X}\n" for count in counts),
    encoding="ascii",
)