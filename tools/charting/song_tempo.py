"""Tempo and offset of a song from its audio alone, for auto_level.py: autocorrelation of the loudness-rise envelope
(beat, half bar, bar and eighth periods together) weighted by a prior around the game's usual tempo, then the BPM
refined on the strongest hits (fit_tempo.coherence) and the offset fitted on the standout hits (hit_level.fit_offset,
the method behind the shipped hit-levels). Measured 2026-10-15 on the 9 shipped songs: every BPM within 0.05 of the
known one; 100-vs-150 and 120-vs-160 songs come back flagged ambiguous so the caller asks instead of guessing.
Usage: python tools/charting/song_tempo.py <song.mp3>   Related: tools/charting/fit_tempo.py, tools/charting/hit_level.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fit_tempo import coherence, strong_hits  # noqa: E402
from hit_level import fit_offset, hit_table  # noqa: E402
from loudness_onsets import FRAME_SEC, decode  # noqa: E402
from tap_salience import envelope, onset_strength  # noqa: E402

BPM_RANGE = (70.0, 200.0)
BPM_STEP = 0.1
# (multiple of the beat period, weight): the beat itself, the half bar, the bar and the eighth note.
PERIODS = ((1.0, 1.0), (2.0, 0.5), (4.0, 0.25), (0.5, 0.25))
# Prior: log-normal around PRIOR_BPM, PRIOR_OCTAVES wide (the shipped songs are 120-150 BPM).
PRIOR_BPM = 125.0
PRIOR_OCTAVES = 0.5
# Peaks closer than this share are one peak (side lobes of the same tempo).
PEAK_SEPARATION = 0.05
# A runner-up scoring at least this share of the best makes the tempo unsure.
AMBIGUOUS = 0.85
# The refined BPM stays within this share of the autocorrelation peak.
REFINE_SHARE = 0.03
REFINE_STEP = 0.01


def autocorrelation(strength):
    centred = strength - strength.mean()
    size = len(centred)
    spectrum = np.fft.rfft(centred, 2 * size)
    result = np.fft.irfft(spectrum * np.conj(spectrum))[:size]
    return result / max(result[0], 1e-12)


def candidates(strength, count=4):
    """[(bpm, score)] best first: the strongest periodicities after the prior."""
    correlation = autocorrelation(strength)
    bpms = np.arange(BPM_RANGE[0], BPM_RANGE[1], BPM_STEP)
    scores = np.zeros(len(bpms))
    for multiple, weight in PERIODS:
        lags = 60.0 / bpms / FRAME_SEC * multiple
        scores += weight * np.interp(lags, np.arange(len(correlation)), correlation)
    scores *= np.exp(-0.5 * (np.log2(bpms / PRIOR_BPM) / PRIOR_OCTAVES) ** 2)
    picked = []
    for index in np.argsort(-scores):
        if all(abs(bpms[index] / other - 1.0) > PEAK_SEPARATION for other, _ in picked):
            picked.append((float(bpms[index]), float(scores[index])))
        if len(picked) == count:
            break
    return picked


def refine(times, weights, bpm):
    """BPM within REFINE_SHARE of `bpm` where the strongest hits line up best on the beat and eighth grids."""
    bpms = np.arange(bpm * (1.0 - REFINE_SHARE), bpm * (1.0 + REFINE_SHARE), REFINE_STEP)
    score = coherence(times, weights, bpms, 1.0)[0] + coherence(times, weights, bpms, 2.0)[0]
    return float(bpms[int(np.argmax(score))])


def offset_for(samples, bpm):
    """Offset (s) in [0, one bar) for a known BPM."""
    table, _ = hit_table(samples, bpm)
    return round(fit_offset(table, bpm), 4)


def estimate(path, bpm=None):
    """{"bpm", "offset", "candidates": [(bpm, score)], "ambiguous": bool}; a given `bpm` is kept as is."""
    samples = decode(path)
    found = candidates(onset_strength(envelope(samples)))
    ambiguous = bpm is None and len(found) > 1 and found[1][1] >= AMBIGUOUS * found[0][1]
    if bpm is None:
        times, weights = strong_hits(path)
        bpm = round(refine(times, weights, found[0][0]), 2)
    return {"bpm": bpm, "offset": offset_for(samples, bpm), "candidates": found, "ambiguous": ambiguous}


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    result = estimate(sys.argv[1])
    print("bpm %.2f  offset %.4f  %s" % (result["bpm"], result["offset"], "AMBIGUOUS" if result["ambiguous"] else "sure"))
    for bpm, score in result["candidates"]:
        print("  candidate %6.1f  score %.3f" % (bpm, score))


if __name__ == "__main__":
    main()
