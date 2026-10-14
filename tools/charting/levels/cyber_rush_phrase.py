"""Cyber Rush, phrase-based: taps on the half-beat grid where the whole mix jumps louder, one motif per section.

Song data (tempo, offset, sections, cameras) comes from the hand chart tools/charting/levels/cyber_rush.py.
Usage: python tools/charting/levels/cyber_rush_phrase.py   Related: tools/charting/phrase_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from cyber_rush import SONG  # noqa: E402
from phrase_level import build_phrase_level  # noqa: E402

RULES = [
    {"start": 8, "end": 56, "taps": 2, "gap": 4.0, "patterns": ["spike", "step", "gap", "spike"]},
    {"start": 60, "end": 124, "taps": 6, "gap": 1.0, "keep_db": 8.0, "patterns": ["spike", "step", "gap", "orb", "spike"]},
    {"start": 124, "end": 172, "taps": 2, "gap": 3.0, "patterns": ["spike", "gap"]},
    {"start": 172, "end": 240, "taps": 7, "gap": 1.0, "keep_db": 8.0, "patterns": ["spike", "step", "dl", "gap", "orb", "dr"]},
    {"start": 240, "end": 284, "taps": 2, "gap": 3.0, "patterns": ["spike", "gap"]},
    {"start": 284, "end": 350, "taps": 10, "gap": 0.5, "min_db": 5.0, "keep_db": 7.0, "patterns": ["spike", "step", "gap", "flip", "orb", "spike", "dl"]},
]

if __name__ == "__main__":
    # Grid refit on whole-mix loudness at every half beat (135 / 1.767 drifts ~0.6 beat by the end).
    build_phrase_level(dict(SONG, bpm=134.72, offset=1.704, path="assets/music/cyber_rush.mp3"), RULES)
