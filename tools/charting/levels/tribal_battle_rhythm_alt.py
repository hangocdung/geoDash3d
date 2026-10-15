"""Tribal Battle Rhythm (Alt Take) (hdgstudio86, 150 BPM), built by hit_level.py on its standout hits: tribal orchestral battle, the hardest: pairs from the second phase, up to four taps a bar.
Difficulty 5 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/tribal_battle_rhythm_alt.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "id": "tribal_battle_rhythm_alt", "title": "Tribal Battle Rhythm (Alt Take)", "artist": "hdgstudio86", "bpm": 150.0, "difficulty": 5,
    "palettes": ["ocean", "ember", "ultraviolet", "sunset", "void"],
}

if __name__ == "__main__":
    build(SONG)
