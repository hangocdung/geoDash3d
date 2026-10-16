"""Neon Highway (hdgstudio86, 115 BPM), built by hit_level.py on its standout hits: synthwave night drive.
Difficulty 1 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/neon_highway.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "neon_highway", "title": "Neon Highway", "artist": "hdgstudio86", "bpm": 115.0, "difficulty": 1,
    "palettes": ["ultraviolet", "ocean", "sunset", "glacier", "void"],
}

if __name__ == "__main__":
    build(SONG)
