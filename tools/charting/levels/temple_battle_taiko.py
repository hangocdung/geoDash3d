"""Temple Battle Taiko (hdgstudio86, 130 BPM), built by hit_level.py on its standout hits: taiko and choir; orb pairs from the fourth phase.
Difficulty 2 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/temple_battle_taiko.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "id": "temple_battle_taiko", "title": "Temple Battle Taiko", "artist": "hdgstudio86", "bpm": 130.0, "difficulty": 2,
    "palettes": ["ocean", "ember", "aurora", "ultraviolet", "void"],
}

if __name__ == "__main__":
    build(SONG)
