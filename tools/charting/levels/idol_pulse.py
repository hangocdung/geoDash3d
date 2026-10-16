"""Idol Pulse (hdgstudio86, 126.8 BPM), built by hit_level.py on its standout hits: K-pop dance stabs.
Difficulty 2 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/idol_pulse.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "idol_pulse", "title": "Idol Pulse", "artist": "hdgstudio86", "bpm": 126.8, "difficulty": 2,
    "palettes": ["ultraviolet", "glacier", "sunset", "aurora", "void"],
}

if __name__ == "__main__":
    build(SONG)
