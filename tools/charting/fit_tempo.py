"""Tempo and offset fitted on a song's strongest hits (what the player taps), for songs the analysis misreads
(e.g. 150 BPM reported as 100). Scores every BPM by how well the loud hits line up on its eighth-note grid, then
picks the beat phase that puts the loudest hits on beat 1 of the bar.
Usage: python tools/charting/fit_tempo.py <song.mp3> [min_bpm] [max_bpm]   (prints the best candidates)
Related: tools/audio/analyze_song.py (first estimate), tools/charting/hit_grid.py (check the result bar by bar)
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loudness_onsets import decode, loudness_hits  # noqa: E402

# Only the loudest share of the hits votes (the standout ones a level is built on).
STRONG_SHARE = 0.4
BPM_STEP = 0.01


def strong_hits(path):
    hits = loudness_hits(decode(path))
    jumps = np.array([jump for _, jump in hits])
    keep = jumps >= np.quantile(jumps, 1.0 - STRONG_SHARE)
    times = np.array([time_sec for time_sec, _ in hits])[keep]
    weights = jumps[keep]
    return times, weights


def coherence(times, weights, bpms, subdivision):
    """|sum w e^(i 2 pi f t)| / sum w for the grid at `subdivision` notes per beat."""
    frequencies = bpms[:, None] / 60.0 * subdivision
    phases = 2.0 * np.pi * frequencies * times[None, :]
    real = (weights[None, :] * np.cos(phases)).sum(1)
    imag = (weights[None, :] * np.sin(phases)).sum(1)
    return np.hypot(real, imag) / weights.sum(), np.arctan2(imag, real)


def best_offset(times, weights, bpm):
    """Offset (s) of a bar line: the eighth-grid phase, then the slot of the bar holding the most hit weight."""
    _, angle = coherence(times, weights, np.array([bpm]), 2.0)
    eighth = 30.0 / bpm
    phase = (angle[0] / (2.0 * np.pi)) * eighth % eighth
    slots = np.round((times - phase) / eighth).astype(int) % 8
    totals = np.bincount(slots, weights=weights, minlength=8)
    return phase + int(np.argmax(totals)) * eighth


def fit(path, low=90.0, high=180.0):
    times, weights = strong_hits(path)
    bpms = np.arange(low, high, BPM_STEP)
    score, _ = coherence(times, weights, bpms, 2.0)
    order = np.argsort(-score)
    picked = []
    for index in order:
        bpm = bpms[index]
        if all(abs(bpm - other) > 1.0 for other, _ in picked):
            picked.append((float(bpm), float(score[index])))
        if len(picked) == 4:
            break
    return [(bpm, value, best_offset(times, weights, bpm)) for bpm, value in picked]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    low = float(sys.argv[2]) if len(sys.argv) > 2 else 90.0
    high = float(sys.argv[3]) if len(sys.argv) > 3 else 180.0
    for bpm, value, offset in fit(sys.argv[1], low, high):
        print("bpm %7.2f  coherence %.3f  offset %.4f" % (bpm, value, offset))


if __name__ == "__main__":
    main()
