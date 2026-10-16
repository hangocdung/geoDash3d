"""Drift Phonk (hdgstudio86, 130 BPM), built by hit_level.py on its standout hits: drift phonk, cowbell and 808 hits.
Difficulty 4 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/drift_phonk.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "drift_phonk", "title": "Drift Phonk", "artist": "hdgstudio86", "bpm": 130.0, "difficulty": 4,
    "palettes": ["indigo", "ultraviolet", "ember", "glacier", "void"],
}

if __name__ == "__main__":
    build(SONG)
