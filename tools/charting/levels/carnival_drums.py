"""Carnival Drums (hdgstudio86, 124 BPM), built by hit_level.py on its standout hits: samba batucada accents.
Difficulty 3 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/carnival_drums.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "carnival_drums", "title": "Carnival Drums", "artist": "hdgstudio86", "bpm": 124.0, "difficulty": 3,
    "palettes": ["ocean", "aurora", "ember", "ultraviolet", "void"],
}

if __name__ == "__main__":
    build(SONG)
