"""Precomputed equalizer data for the LED wall on the road's camera-side face: 16 log-spaced bands at 30 frames a
second with VU-meter ballistics (instant rise, ~0.35 s fall) and a peak dot that holds then drops. The game reads
it as a function of the song time (SongClock), so the LEDs stay locked to the music in captures and practice too.
Output assets/music/<id>.spectrum.json: {"fps", "bands", "frames", "row", "data"} where data is base64 RG8 pixels
(R = level, G = peak) of an image `row` frames wide and bands x ceil(frames / row) tall (frame f, band k sits at
x = f % row, y = (f // row) * bands + k), so long songs stay under mobile texture size limits.
Usage: python tools/audio/build_spectrum.py [<id> ...]   (no id: every assets/music/*.mp3)
Related: src/presentation/track/spectrum_texture.gd, src/presentation/shaders/neon_track.gdshaderinc
"""
import base64
import glob
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "charting"))
from loudness_onsets import SAMPLE_RATE, decode  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FPS = 30
BANDS = 16
ROW = 2048
WINDOW = 2048
LOW_HZ, HIGH_HZ = 40.0, 11000.0
FALL_SEC = 0.35
PEAK_HOLD_SEC = 0.5
PEAK_FALL_PER_SEC = 1.2
# Level shaping: per band, the 10th..99th percentile dB range maps to 0..1, then this exponent adds bounce.
LOW_PERCENTILE, HIGH_PERCENTILE = 10.0, 99.0
SHAPE = 1.4


def band_levels(samples):
    hop = SAMPLE_RATE / FPS
    frames = int(len(samples) / hop)
    window = np.hanning(WINDOW).astype(np.float32)
    padded = np.concatenate([np.zeros(WINDOW // 2, np.float32), samples, np.zeros(WINDOW, np.float32)])
    frequencies = np.fft.rfftfreq(WINDOW, 1.0 / SAMPLE_RATE)
    edges = np.geomspace(LOW_HZ, HIGH_HZ, BANDS + 1)
    masks = [(frequencies >= edges[i]) & (frequencies < edges[i + 1]) for i in range(BANDS)]
    power = np.zeros((frames, BANDS), np.float32)
    for frame in range(frames):
        start = int(frame * hop)
        spectrum = np.abs(np.fft.rfft(padded[start:start + WINDOW] * window)) ** 2
        power[frame] = [spectrum[mask].mean() if mask.any() else 0.0 for mask in masks]
    decibels = 10.0 * np.log10(power + 1e-10)
    low = np.percentile(decibels, LOW_PERCENTILE, axis=0)
    high = np.percentile(decibels, HIGH_PERCENTILE, axis=0)
    return np.clip((decibels - low) / np.maximum(high - low, 1e-6), 0.0, 1.0) ** SHAPE


def ballistics(raw):
    """VU meter: instant rise, linear fall; peak dot holds PEAK_HOLD_SEC then falls."""
    level = np.zeros_like(raw)
    peak = np.zeros_like(raw)
    hold = np.zeros(raw.shape[1])
    fall = 1.0 / (FALL_SEC * FPS)
    for frame in range(raw.shape[0]):
        previous = level[frame - 1] if frame else np.zeros(raw.shape[1])
        level[frame] = np.maximum(raw[frame], previous - fall)
        previous_peak = peak[frame - 1] if frame else np.zeros(raw.shape[1])
        rising = level[frame] >= previous_peak
        hold = np.where(rising, PEAK_HOLD_SEC * FPS, hold - 1)
        dropped = np.where(hold > 0, previous_peak, previous_peak - PEAK_FALL_PER_SEC / FPS)
        peak[frame] = np.where(rising, level[frame], np.maximum(dropped, level[frame]))
    return level, peak


def pack(level, peak):
    frames = level.shape[0]
    blocks = (frames + ROW - 1) // ROW
    image = np.zeros((blocks * BANDS, ROW, 2), np.uint8)
    for frame in range(frames):
        block, x = divmod(frame, ROW)
        image[block * BANDS:(block + 1) * BANDS, x, 0] = np.round(level[frame] * 255)
        image[block * BANDS:(block + 1) * BANDS, x, 1] = np.round(peak[frame] * 255)
    return base64.b64encode(image.tobytes()).decode("ascii")


def build(song_id):
    samples = decode(os.path.join(ROOT, "assets", "music", song_id + ".mp3"))
    level, peak = ballistics(band_levels(samples))
    data = {"fps": FPS, "bands": BANDS, "frames": int(level.shape[0]), "row": ROW, "data": pack(level, peak)}
    path = os.path.join(ROOT, "assets", "music", song_id + ".spectrum.json")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle)
    print("wrote %s: %d frames, %.0f KB" % (os.path.relpath(path, ROOT), level.shape[0], os.path.getsize(path) / 1024))


def main():
    ids = sys.argv[1:] or sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(ROOT, "assets", "music", "*.mp3")))
    for song_id in ids:
        build(song_id)


if __name__ == "__main__":
    main()
