"""Titan March (hdgstudio86, 120 BPM), built by hit_level.py on its standout hits: epic orchestral march, drums and brass stabs.
Difficulty 1 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/titan_march.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "titan_march", "title": "Titan March", "artist": "hdgstudio86", "bpm": 120.0, "difficulty": 1,
    "palettes": ["ocean", "glacier", "sunset", "indigo", "void"],
}

if __name__ == "__main__":
    build(SONG)
