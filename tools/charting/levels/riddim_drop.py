"""Riddim Drop (hdgstudio86, 148 BPM), built by hit_level.py on its standout hits: riddim dubstep bass stabs.
Difficulty 5 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/riddim_drop.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "riddim_drop", "title": "Riddim Drop", "artist": "hdgstudio86", "bpm": 148.0, "difficulty": 5,
    "palettes": ["indigo", "ultraviolet", "glacier", "ember", "void"],
}

if __name__ == "__main__":
    build(SONG)
