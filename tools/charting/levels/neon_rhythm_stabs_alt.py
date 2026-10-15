"""Neon Rhythm Stabs (Alt Take) (hdgstudio86, 136 BPM), built by hit_level.py on its standout hits: synthwave stabs, faster take.
Difficulty 3 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/neon_rhythm_stabs_alt.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "id": "neon_rhythm_stabs_alt", "title": "Neon Rhythm Stabs (Alt Take)", "artist": "hdgstudio86", "bpm": 136.0, "difficulty": 3,
    "palettes": ["indigo", "ultraviolet", "aurora", "sunset", "void"],
}

if __name__ == "__main__":
    build(SONG)
