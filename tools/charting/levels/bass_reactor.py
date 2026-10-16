"""Bass Reactor (hdgstudio86, 150 BPM), built by hit_level.py on its standout hits: half-time drum and bass stabs.
Difficulty 4 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/bass_reactor.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "bass_reactor", "title": "Bass Reactor", "artist": "hdgstudio86", "bpm": 150.0, "difficulty": 4,
    "palettes": ["glacier", "indigo", "aurora", "ultraviolet", "void"],
}

if __name__ == "__main__":
    build(SONG)
