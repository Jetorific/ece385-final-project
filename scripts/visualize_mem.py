import argparse
import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


def load_mem(path, expected_samples=2048):
    """Read one 16-bit hexadecimal sample per nonblank, noncomment line."""
    samples = []

    with Path(path).open("r", encoding="utf-8-sig") as file:
        for line_number, line in enumerate(file, start=1):
            # Allow blank lines and trailing // or # comments.
            token = line.split("//", 1)[0].split("#", 1)[0].strip()

            if not token:
                continue

            # Accept either FFFF or 0xFFFF.
            digits = token[2:] if token.lower().startswith("0x") else token

            if (
                not 1 <= len(digits) <= 4
                or any(c not in "0123456789abcdefABCDEF" for c in digits)
            ):
                raise ValueError(
                    f"Line {line_number}: expected one 16-bit hex word, "
                    f"got {token!r}"
                )

            value = int(digits, 16)

            # Interpret bit 15 as the two's-complement sign bit.
            if value & 0x8000:
                value -= 0x10000

            samples.append(value)

    if len(samples) != expected_samples:
        raise ValueError(
            f"Expected {expected_samples} samples, found {len(samples)}."
        )

    return np.array(samples, dtype=np.int16)


def positive_rate(text):
    value = float(text)
    if not math.isfinite(value) or value <= 0:
        raise argparse.ArgumentTypeError(
            "Sample rate must be a finite number greater than zero."
        )
    return value


def main():
    parser = argparse.ArgumentParser(
        description="Plot 2048 signed 16-bit hexadecimal samples from a .mem file."
    )
    parser.add_argument("file", type=Path, help="Path to the .mem file")
    parser.add_argument(
        "--fs",
        type=positive_rate,
        help="Sample rate in Hz; otherwise use sample index",
    )
    parser.add_argument(
        "--save",
        type=Path,
        help="Also save the plot, e.g. waveform.png",
    )
    parser.add_argument(
        "--step",
        action="store_true",
        help="Draw a staircase waveform instead of connecting samples with lines",
    )
    args = parser.parse_args()

    try:
        samples = load_mem(args.file)
    except (OSError, ValueError) as error:
        parser.error(str(error))

    x = np.arange(samples.size)
    xlabel = "Sample index"

    if args.fs is not None:
        x = x / args.fs
        xlabel = "Time (s)"

    fig, ax = plt.subplots(figsize=(12, 5))

    if args.step:
        ax.step(x, samples, where="post", linewidth=1)
    else:
        ax.plot(x, samples, linewidth=1)

    ax.set(
        title=f"{args.file.name} — {samples.size} samples",
        xlabel=xlabel,
        ylabel="Signed sample value",
        ylim=(-32768, 32767),
        xlim=(x[0], x[-1]),
    )
    ax.axhline(0, color="gray", linewidth=0.7)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()

    print(f"Samples: {samples.size}")
    print(f"Minimum: {samples.min()}")
    print(f"Maximum: {samples.max()}")
    print(f"Mean:    {samples.mean():.2f}")

    if args.save:
        fig.savefig(args.save, dpi=200)
        print(f"Saved plot to {args.save}")

    plt.show()


if __name__ == "__main__":
    main()