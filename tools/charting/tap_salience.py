"""Tap salience: does each tap land on a hit that clearly stands out from the music around it?

Two medians over the taps (jump / orb / dodge / flip / roll cues) of a chart:
- standout: onset strength at the tap (largest rise of the mix loudness within +-30 ms) over the mean strength
  at the eight quarter-beat slots within +-1 beat (is the tapped hit the one that stands out?);
- attack: loudness just after the tap (max over 60 ms) over loudness just before it (10-60 ms earlier).
Measured 2026-10-15: the reference the_dawn_assembly x1.95 / x6.2, fault_line x1.77 / x4.4, pulse_drive
x2.03 / x3.2; the songs whose taps "felt off" x0.9-1.3 / x1.6-2.9 (dense mixes, every tap still on an onset).
A song is fit for a level when both medians clear GOOD_STANDOUT and GOOD_ATTACK (memory: tap-on-standout-hits).
Usage: python tools/charting/tap_salience.py [chart.json ...]   (no argument: every chart in assets/music)
Related: tools/charting/loudness_onsets.py (decoding), docs/design/music_prompts.md
"""
import glob
import json
import os
import statistics
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loudness_onsets import FRAME_SEC, HOP, decode  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
TAP_TYPES = {"jump", "orb", "orb_big", "orb_drop", "dodge_left", "dodge_right", "flip", "roll", "flip_down", "flip_up"}
WINDOW_SEC = 0.03
NEIGHBOUR_SLOTS = [-1.0, -0.75, -0.5, -0.25, 0.25, 0.5, 0.75, 1.0]
GOOD_STANDOUT = 1.6
GOOD_ATTACK = 3.0
ATTACK_AFTER_FRAMES = 12
ATTACK_BEFORE_FRAMES = (12, 2)


def envelope(samples):
    frames = len(samples) // HOP
    return np.sqrt((samples[:frames * HOP].reshape(-1, HOP) ** 2).mean(1) + 1e-12)


def onset_strength(rms):
    """Per-frame rise of the RMS envelope (linear), lightly smoothed."""
    rise = np.maximum(np.diff(rms, prepend=rms[0]), 0.0)
    return np.convolve(rise, np.ones(3) / 3.0, mode="same")


def attack_at(rms, time_sec):
    frame = int(round(time_sec / FRAME_SEC))
    before = rms[max(frame - ATTACK_BEFORE_FRAMES[0], 0):max(frame - ATTACK_BEFORE_FRAMES[1], 1)].mean()
    return float(rms[frame:frame + ATTACK_AFTER_FRAMES].max() / max(before, 1e-9))


def strength_at(strength, time_sec):
    center = int(round(time_sec / FRAME_SEC))
    reach = int(round(WINDOW_SEC / FRAME_SEC))
    lo, hi = max(center - reach, 0), min(center + reach + 1, len(strength))
    return float(strength[lo:hi].max()) if hi > lo else 0.0


def chart_salience(path):
    """(standout ratios, attack ratios), one per tap."""
    chart = json.load(open(path, encoding="utf-8"))
    song = os.path.join(ROOT, chart["song"].replace("res://", ""))
    rms = envelope(decode(song))
    strength = onset_strength(rms)
    bpm = chart["tempo"][0]["bpm"]
    offset = chart["offset_sec"]
    seconds_per_beat = 60.0 / bpm
    standout, attack = [], []
    for event in chart["events"]:
        if event["type"] not in TAP_TYPES:
            continue
        time_sec = offset + event["beat"] * seconds_per_beat
        tap = strength_at(strength, time_sec)
        around = [strength_at(strength, time_sec + slot * seconds_per_beat) for slot in NEIGHBOUR_SLOTS]
        standout.append(tap / max(sum(around) / len(around), 1e-9))
        attack.append(attack_at(rms, time_sec))
    return standout, attack


def main():
    paths = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT, "assets", "music", "*.chart.json")))
    for path in paths:
        standout, attack = chart_salience(path)
        if not standout:
            print("%-48s no taps" % os.path.basename(path))
            continue
        median_standout, median_attack = statistics.median(standout), statistics.median(attack)
        verdict = "OK" if median_standout >= GOOD_STANDOUT and median_attack >= GOOD_ATTACK else "WEAK"
        print("%-48s taps %3d  standout x%.2f  attack x%.2f  %s" % (os.path.basename(path), len(standout),
              median_standout, median_attack, verdict))


if __name__ == "__main__":
    main()
