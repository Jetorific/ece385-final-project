from math import floor
from pathlib import Path

# STATEGY:
#  1. Find the lowest possible frequency
#  2. Calculate requested frequency
#  3. Count increment = (requested frequency) / (lowest frequency)
#  4. Round the increment to an integer and store it to ROM

CLK_HZ = 100_000_000
COUNT_BITS = 32
SAMPLE_IDX_BITS = 11  # 2**11 = 2048 samples

min_hz = CLK_HZ / (2**COUNT_BITS)

counts = []
errors = []
for note in range(128):
    hz = 440.0 * 2.0 ** ((note - 69) / 12.0)
    count_increment = hz/min_hz
    rounded = floor(round(count_increment))
    freq_error = hz - rounded*min_hz
    print(f"{note} error: {freq_error} Hz")
    counts.append(rounded)
    errors.append(freq_error)

    assert freq_error <= 0.1, (note, freq_error, rounded, hz, min_hz)

print()
print(f"Max error magnitude: {max([abs(error) for error in errors])} Hz")
print(f"Average error: {sum(errors)/len(errors)} Hz")
print(f"Standard deviation: {(sum([(error - sum(errors)/len(errors))**2 for error in errors])/len(errors))**0.5} Hz")

Path("scripts/midi_wavetable_counts.mem").write_text(
    "".join(f"{count:06X}\n" for count in counts),
    encoding="ascii",
)