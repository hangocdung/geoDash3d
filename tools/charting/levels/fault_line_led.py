"""Fault Line (LED), a test of an LED-driven level: taps where the LED equalizer on the road's side jumps up, bursts
of continuous taps in the loud sections and underside runs (flip_down, jumps under the track, flip_up) every 24
beats where the taps allow (led_level.py). Shares the song (and its LED data) with fault_line; the song sits on its
beat grid (verified by the hand chart), so taps snap to quarter beats.
Usage: python tools/charting/levels/fault_line_led.py   Related: tools/charting/led_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from led_level import build  # noqa: E402

SONG = {
    "id": "fault_line_led", "audio": "fault_line", "title": "Fault Line (LED)", "artist": "hdgstudio86",
    "bpm": 128.0, "offset": 0.448, "difficulty": 4, "grid": 0.25, "under_every": 24, "end_beat": 332,
    "palettes": ["glacier", "indigo", "aurora", "ember", "void"],
}

if __name__ == "__main__":
    build(SONG)
