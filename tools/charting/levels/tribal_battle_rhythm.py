"""Tribal Battle Rhythm (hdgstudio86, 150 BPM), built by hit_level.py on its standout hits: tribal orchestral battle; the analysis reads 100 BPM (3:2), the prompt and the hits say 150.
Difficulty 4 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/tribal_battle_rhythm.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "id": "tribal_battle_rhythm", "title": "Tribal Battle Rhythm", "artist": "hdgstudio86", "bpm": 150.0, "difficulty": 4,
    "palettes": ["indigo", "sunset", "aurora", "ember", "void"],
}

if __name__ == "__main__":
    build(SONG)
