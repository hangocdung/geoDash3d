"""Savanna Drums (hdgstudio86, 110 BPM), built by hit_level.py on its standout hits: West African drum ensemble accents.
Difficulty 2 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/savanna_drums.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "savanna_drums", "title": "Savanna Drums", "artist": "hdgstudio86", "bpm": 110.0, "difficulty": 2,
    "palettes": ["ocean", "sunset", "aurora", "glacier", "void"],
}

if __name__ == "__main__":
    build(SONG)
