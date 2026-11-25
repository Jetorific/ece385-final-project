# Paper Synthesizer

A playable MIDI instrument that takes a picture of a hand-drawn waveform and turns it into a wavetable synth. This is our ECE385 (Digital Systems Laboratory) final project.

By Jet Trommer and Michael Bauer. University of Illinois Urbana-Champaign.

## How It Works

1. **Camera:** An OV7670 camera captures the hand-drawn waveform.
2. **Fit:** A curve is traced onto the image data and sampled into a single-cycle wavetable.
3. **Play:** MIDI is obtained over USB from a piano keyboard, then decoded to drive polyphonic wavetable oscillators.
4. **Output:** A P5102A DAC decodes digital audio into a stereo output signal.

## Features

**Baseline**
- [x] MIDI input from a modern keyboard
- [ ] Camera-based waveform capture
- [x] Wavetable synthesis from one captured waveform
- [x] Polyphony
- [x] Audio output up to 20 kHz

**Stretch goals**
- [ ] Live camera view and traced-waveform display
- [ ] MIDI keyboard visualizer
- [ ] Chord interpreter
- [ ] Envelopes, LFOs, and filters

## Hardware

- Urbana FPGA Board (Vivado project)
- OV7670 camera
- External P1502A DAC
- MIDI adapter and a MIDI keyboard
- Optional HDMI display

## Status

Work in progress. See the project proposal for the timeline.