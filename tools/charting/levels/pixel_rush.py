"""Pixel Rush (hdgstudio86, 144 BPM), built by hit_level.py on its standout hits: chiptune 8-bit arcade.
Difficulty 3 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/pixel_rush.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "pixel_rush", "title": "Pixel Rush", "artist": "hdgstudio86", "bpm": 144.0, "difficulty": 3,
    "palettes": ["indigo", "aurora", "ultraviolet", "glacier", "void"],
}

if __name__ == "__main__":
    build(SONG)
