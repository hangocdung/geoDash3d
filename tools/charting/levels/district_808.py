"""808 District (hdgstudio86, 144 BPM), built by hit_level.py on its standout hits: hard trap, 808 and snare hits.
Difficulty 4 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/district_808.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "district_808", "title": "808 District", "artist": "hdgstudio86", "bpm": 144.0, "difficulty": 4,
    "palettes": ["glacier", "ultraviolet", "ember", "indigo", "void"],
}

if __name__ == "__main__":
    build(SONG)
