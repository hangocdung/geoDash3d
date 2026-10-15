"""Pulse Drive (LED), a test of an LED-driven level: taps where the LED equalizer on the road's side jumps up, with
bursts of continuous taps in the loud sections and underside runs every 24 beats where the taps allow (led_level.py).
Shares the song (and its LED data) with pulse_drive; the song sits on its beat grid (verified by the hand chart), so
taps snap to quarter beats.
Usage: python tools/charting/levels/pulse_drive_led.py   Related: tools/charting/led_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from led_level import build  # noqa: E402

SONG = {
    "id": "pulse_drive_led", "audio": "pulse_drive", "title": "Pulse Drive (LED)", "artist": "hdgstudio86",
    "bpm": 122.0, "offset": 0.5025, "difficulty": 4, "grid": 0.25, "under_every": 24,
    "palettes": ["ocean", "indigo", "sunset", "ultraviolet", "void"],
}

if __name__ == "__main__":
    build(SONG)
