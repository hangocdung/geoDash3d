"""Neon Rhythm Stabs (hdgstudio86, 130 BPM), built by hit_level.py on its standout hits: synthwave stabs; up to three taps a bar at the end.
Difficulty 3 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/neon_rhythm_stabs.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "id": "neon_rhythm_stabs", "title": "Neon Rhythm Stabs", "artist": "hdgstudio86", "bpm": 130.0, "difficulty": 3,
    "palettes": ["ultraviolet", "ocean", "sunset", "glacier", "void"],
}

if __name__ == "__main__":
    build(SONG)
