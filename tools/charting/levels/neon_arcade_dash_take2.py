"""Neon Arcade Dash (Take 2), hand-charted on its actual hit times (~125.9 BPM, the tempo wanders).

The groove drifts against any fixed grid (the analysis said 124.5 BPM; 125.894 fits best overall but hits still
wander by up to ~1/4 beat), so every tap is a measured kick/snare onset time on the 125.894 grid, not a
rounded beat. Mostly single taps; orbs only where two hits are half a beat apart.
Intro 0-28, drop 28-96, verse 96-160, silent break 160-176, drop 2 176-240, final 240-304.
Usage: python tools/charting/levels/neon_arcade_dash_take2.py   Related: tools/charting/handmade.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from handmade import build  # noqa: E402

SONG = {
    "id": "neon_arcade_dash_take2", "title": "Neon Arcade Dash (Take 2)", "artist": "Unknown", "bpm": 125.894,
    "offset": 1.307, "end_beat": 306,
    "phases": [(0, "ultraviolet", 7.0), (28, "ocean", 7.75), (96, "aurora", 8.5), (176, "sunset", 9.25), (240, "ember", 10.0)],
    "sections": [(-16, "intro", 0.3), (28, "drop", 0.85), (96, "verse", 0.75), (160, "break", 0.25),
                 (176, "drop2", 0.85), (240, "final", 1.0), (304, "outro", 0.3)],
    "cameras": [(-8, "front", 0), (-2, "side", 4), (28, "side_far", 2), (96, "side", 2), (160, "side", 4),
                (176, "side_far", 2), (200, "diagonal", 2), (240, "side_far", 2), (252, "diagonal", 2),
                (284, "side_high", 2)],
    "track": [(0, {"shape": "straight"}), (96, {"shape": "turn", "angle_deg": 30}), (104, {"shape": "straight"}),
              (160, {"shape": "turn", "angle_deg": -30}), (168, {"shape": "straight"}),
              (240, {"shape": "turn", "angle_deg": 35}), (248, {"shape": "straight"})],
    "vfx": [(28, "flash"), (28, "shockwave"), (176, "flash"), (176, "shockwave"), (240, "flash"), (240, "shockwave"),
            (304, "burst")],
}

STEPS = """
; intro
7.91:spike 11.92:step 14.36:spike 15.97:gap 18.5:spike 22.21:gap 26:drop
; drop: the big hits (marked strong in the onset list)
29.13:spike 30.9:spike 32.42:step 33.94:spike 35.73:gap 39:step 40.5:spike 42.02:gap 43.03:drop
44.03:spike 45.56:step 47.08:spike 48.6:orb 50.61:gap 53.19:drop 54.15:spike 55.65:step 57.19:spike
59.21:gap 61.22:spike 64.78:drop 66.28:spike 68.83:step 70.33:spike 71.83:gap 73.38:drop 74.38:spike
77.18:step 79.93:spike 80.94:spike 82.98:gap 84.99:spike 86.51:spike 88:drop 91.57:spike 92.58:step 93.85:spike
95.87:gap
; verse: steady kicks
97.39:spike 99:drop 100.68:spike 102.43:step 103.95:spike 105.47:gap 106.97:spike 108:drop 108.81:spike
112.05:step 113.55:spike 115.09:gap 117.6:spike 120.13:spike 121.65:drop 123.17:spike 124.45:step 126.46:spike
128.23:gap 130.25:drop 131.84:spike 134.3:spike 136.31:step 137.83:spike 139.38:gap 141.41:spike 142.65:drop
144.41:spike 145.91:step 147.46:spike 149.96:gap 152.99:spike 154.53:drop 155.54:spike 158.07:spike
; drop 2: hits every half beat at the start
177:orb 179.04:gap 181.1:spike 184.12:spike 185.62:drop 186.62:spike 188.12:step 189.15:spike 190.94:gap
193.7:spike 195.22:step 198.02:gap 199.29:drop 200.25:spike 202.09:dl 204.33:spike 206.36:flip 208.38:spike
210.19:step 212.41:spike 215.34:gap 216.34:drop 217.96:spike 218.99:spike 220.51:step 221.79:spike 223.55:gap
228.59:spike 230.42:drop 231.52:spike 233.67:step 235.68:spike 237.72:gap 239.24:drop
; final: chains and orbs where the hits run in beats / half beats
242.64:spike 243.85:step 245.02:spike 247.55:gap 250.08:spike 251.6:drop 253.12:spike 254.93:dr 258.18:spike
259.68:step 261.24:spike 264.24:gap 266.26:spike 267.78:drop 269.32:spike 271.09:step 272.34:chain3 275.86:drop
277.38:spike 279.91:flip 282.44:spike 283.96:orb 285.77:spike 287.99:gap 290.52:spike 291.52:drop 292.58:chain2
295.06:step 296.07:orb 299.11:gap 300.11:drop 301.15:trip 303.68:spike
"""

if __name__ == "__main__":
    build(SONG, STEPS)
