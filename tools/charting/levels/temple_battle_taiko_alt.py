"""Temple Battle Taiko (Alt Take) (hdgstudio86, 120 BPM), built by hit_level.py on its standout hits: taiko and choir, the gentlest of the six: one tap a bar at first, no orb pairs.
Difficulty 1 of 5 (taps per bar, spacing and speed ladder: hit_level.DIFFICULTY); offset fitted on the strong hits.
Usage: python tools/charting/levels/temple_battle_taiko_alt.py   Related: tools/charting/hit_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from hit_level import build  # noqa: E402

SONG = {
    "id": "temple_battle_taiko_alt", "title": "Temple Battle Taiko (Alt Take)", "artist": "hdgstudio86", "bpm": 120.0, "difficulty": 1,
    "palettes": ["indigo", "aurora", "ocean", "sunset", "glacier"],
}

if __name__ == "__main__":
    build(SONG)
