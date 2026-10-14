"""Loudness jumps: moments where the whole mix (every band) gets clearly louder than just before.

Taps on these feel locked to the music whatever instrument makes the hit (bass, lead, crash, vocal), which
kick/snare onsets do not on dense, compressed mixes (see the 2026-10-14 comparison in docs/roadmap.md).
jump = loudest level in the 150 ms after a frame - mean level 20-180 ms before it (dB); hits are local
maxima of the jump >= MIN_JUMP_DB, at least MIN_GAP_SEC apart.
Usage: from loudness_onsets import LoudnessOnsets   (decodes the song with ffmpeg)
Related: tools/charting/terrain_level.py (--onsets loudness)
"""
import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile

FFMPEG = os.environ.get("FFMPEG", "D:/ffmpeg-8.1-essentials_build/bin/ffmpeg.exe")
SAMPLE_RATE = 22050
FRAME_SEC = 0.005
AFTER_FRAMES = 30
BEFORE = (4, 36)
MIN_JUMP_DB = 6.0
MIN_GAP_SEC = 0.09


def decode(path):
    with tempfile.TemporaryDirectory() as folder:
        wav = os.path.join(folder, "song.wav")
        subprocess.run([FFMPEG, "-v", "error", "-y", "-i", path, "-ac", "1", "-ar", str(SAMPLE_RATE), wav], check=True)
        rate, samples = wavfile.read(wav)
    return samples.astype(np.float32) / 32768.0


def loudness_hits(samples):
    """(time_sec, jump_db) of every loudness jump."""
    hop = int(FRAME_SEC * SAMPLE_RATE)
    frames = len(samples) // hop
    level = 10.0 * np.log10((samples[:frames * hop].reshape(-1, hop) ** 2).mean(1) + 1e-10)
    jump = np.full(frames, -99.0)
    for i in range(BEFORE[1], frames - AFTER_FRAMES):
        jump[i] = level[i:i + AFTER_FRAMES].max() - level[i - BEFORE[1]:i - BEFORE[0]].mean()
    gap = int(MIN_GAP_SEC / FRAME_SEC)
    hits = []
    for i in range(BEFORE[1], frames - AFTER_FRAMES):
        if jump[i] < MIN_JUMP_DB or jump[i] < jump[max(i - gap, 0):i + gap + 1].max():
            continue
        # The hit starts where the level climbs fastest within the jump window.
        start = i + int(np.argmax(np.diff(level[i - 2:i + AFTER_FRAMES // 2]))) - 1
        hits.append((start * FRAME_SEC, float(jump[i])))
    return hits


class LoudnessOnsets:
    """Same interface as terrain_level.Onsets: beats, strengths (jump dB), percentile, strength_near."""

    def __init__(self, song_path, bpm, offset):
        self.seconds_per_beat = 60.0 / bpm
        hits = loudness_hits(decode(song_path))
        self.beats = [(time_sec - offset) / self.seconds_per_beat for time_sec, _ in hits]
        self.strengths = [jump for _, jump in hits]
        self._sorted = sorted(self.strengths)

    def percentile(self, fraction):
        return self._sorted[min(int(fraction * len(self._sorted)), len(self._sorted) - 1)]

    def strength_near(self, beat, tolerance_sec):
        tolerance = tolerance_sec / self.seconds_per_beat
        return max((s for b, s in zip(self.beats, self.strengths) if abs(b - beat) <= tolerance), default=0.0)
