#!/usr/bin/env python3

import argparse
from pathlib import Path

import numpy as np
from scipy.io import wavfile


FRAME_SIZE = 2048


def convert(input_path, output_path, frame_number, prefix=False):
    sample_rate, audio = wavfile.read(input_path)

    if audio.ndim != 1:
        raise ValueError(
            f"Expected a mono WAV; received audio with shape {audio.shape}."
        )

    if audio.dtype.kind != "f" or audio.dtype.itemsize != 4:
        raise ValueError(
            f"Expected a 32-bit float WAV; received {audio.dtype}."
        )

    if audio.size == 0 or audio.size % FRAME_SIZE != 0:
        raise ValueError(
            f"Input contains {audio.size} samples. Expected a nonzero "
            f"multiple of {FRAME_SIZE}."
        )

    frame_count = audio.size // FRAME_SIZE

    if not 1 <= frame_number <= frame_count:
        raise ValueError(
            f"Frame number must be between 1 and {frame_count}; "
            f"received {frame_number}."
        )

    start = (frame_number - 1) * FRAME_SIZE
    samples = audio[start:start + FRAME_SIZE].astype(np.float64)

    if not np.all(np.isfinite(samples)):
        raise ValueError("Selected frame contains NaN or infinite values.")

    clipped_count = int(np.count_nonzero(np.abs(samples) > 1.0))

    signed = np.clip(
        np.rint(np.clip(samples, -1.0, 1.0) * 32768.0),
        -32768,
        32767,
    ).astype(np.int16)

    hex_prefix = "0x" if prefix else ""

    with output_path.open("w", encoding="ascii", newline="\n") as output:
        for sample in signed:
            output.write(f"{hex_prefix}{int(sample) & 0xFFFF:04X}\n")

    print(f"Selected frame: {frame_number} of {frame_count}")
    print(f"Wrote {signed.size} samples to {output_path}")
    print(f"Input sample rate: {sample_rate} Hz; no resampling performed.")
    print(f"Integer range: {int(signed.min())} to {int(signed.max())}")

    if clipped_count:
        print(
            f"Warning: clipped {clipped_count} samples "
            "outside [-1.0, +1.0]."
        )


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Extract one 2048-sample frame from a float32 WAV "
            "and write signed 16-bit hexadecimal text."
        )
    )
    parser.add_argument("input", type=Path, help="Input float32 WAV")
    parser.add_argument("output", type=Path, help="Output hex text file")
    parser.add_argument(
        "frame",
        type=int,
        help="Frame number to convert: 1 = first wave, 2 = second, etc.",
    )
    parser.add_argument(
        "--prefix",
        action="store_true",
        help="Include 0x before each hexadecimal value",
    )

    args = parser.parse_args()

    if args.input.resolve() == args.output.resolve():
        parser.error("Input and output paths must be different.")

    try:
        convert(args.input, args.output, args.frame, args.prefix)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Error: {error}\n")


if __name__ == "__main__":
    main()
