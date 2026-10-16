"""Steel Factory (hdgstudio86, 130 BPM), built by hit_level.py on its standout hits: industrial techno, anvil and kick hits.
Difficulty 3 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/steel_factory.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "dir": "assets/music/remote", "id": "steel_factory", "title": "Steel Factory", "artist": "hdgstudio86", "bpm": 130.0, "difficulty": 3,
    "palettes": ["glacier", "indigo", "ultraviolet", "ocean", "void"],
}

if __name__ == "__main__":
    build(SONG)
