"""The Dawn Assembly (LED), a test of an LED-driven level on the most precisely timed song: taps where the LED
equalizer on the road's side jumps up, bursts of continuous taps in the loud sections and underside runs (flip_down,
jumps under the track, flip_up) every 24 beats where the taps allow (led_level.py). Shares the song (and its LED
data) with the_dawn_assembly; the song sits on its beat grid, so taps snap to quarter beats.
Usage: python tools/charting/levels/the_dawn_assembly_led.py   Related: tools/charting/led_level.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from led_level import build  # noqa: E402

SONG = {
    "id": "the_dawn_assembly_led", "audio": "the_dawn_assembly", "title": "The Dawn Assembly (LED)",
    "artist": "Google Flow Music (AI)", "bpm": 120.0, "offset": 0.058, "difficulty": 3, "grid": 0.25, "under_every": 24,
    "palettes": ["indigo", "aurora", "sunset", "ultraviolet", "ember"],
}

if __name__ == "__main__":
    build(SONG)
