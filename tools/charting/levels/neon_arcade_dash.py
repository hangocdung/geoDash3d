"""Neon Arcade Dash, hand-charted phrase by phrase on its drum hits (124 BPM, steady).

Beat numbers follow the analysis grid, where the four-on-the-floor kick sits on x.5 and phrases open with a
big kick on x.5. The drop motif is snare hits on 1.5 / 2.25 / 3.0 (0.75 apart) -> fast stairs.
Intro 0-44, drop 44-108, drop 2 112-168, drop 3 180-244, hi-hat break 244-276, build 276-312, final 312-364.
Usage: python tools/charting/levels/neon_arcade_dash.py   Related: tools/charting/handmade.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from handmade import build  # noqa: E402

SONG = {
    "id": "neon_arcade_dash", "title": "Neon Arcade Dash", "artist": "Unknown", "bpm": 124.0, "offset": 1.258,
    "end_beat": 364,
    "phases": [(0, "indigo", 7.0), (44, "ocean", 7.75), (112, "ultraviolet", 8.5), (180, "sunset", 9.25), (312, "void", 10.0)],
    "sections": [(-16, "intro", 0.25), (44, "drop", 0.8), (108, "dip", 0.5), (112, "drop2", 0.85),
                 (168, "mid", 0.6), (180, "drop3", 0.9), (244, "break", 0.4), (276, "quiet", 0.3),
                 (292, "build", 0.6), (312, "final", 1.0), (364, "outro", 0.3)],
    "cameras": [(-8, "front", 0), (-2, "side", 4), (44, "side_far", 2), (112, "side", 2), (136, "diagonal", 2),
                (168, "side", 2), (180, "side_far", 2), (204, "diagonal", 2), (244, "side", 4), (312, "diagonal", 2),
                (344, "side_high", 2)],
    "track": [(0, {"shape": "straight"}), (108, {"shape": "turn", "angle_deg": 30}), (116, {"shape": "straight"}),
              (244, {"shape": "turn", "angle_deg": -35}), (252, {"shape": "straight"}),
              (276, {"shape": "slope", "rise": 3}), (284, {"shape": "straight"})],
    "vfx": [(44, "flash"), (44, "shockwave"), (112, "flash"), (112, "shockwave"), (180, "flash"), (180, "shockwave"),
            (312, "flash"), (312, "shockwave"), (364, "burst")],
}

STEPS = """
; intro (quiet): hits on x.5 and the hi-hat on 2.5, kept light
8.5:spike 12:step 15:gap 18.5:spike 20:step 22.5:gap 23.5:drop 26.5:spike 29.5:step 32.5:spike 34.5:step 37.5:gap
39.5:drop 43.5:spike
; drop: snare stairs on 1.5 / 2.25 / 3.0
44.5:spike 46.25:step 47:gap 48:drop 49.5:stairs 53.5:gap 55:drop 56.5:chain2 61.5:stairs 64.5:gap
66:drop 68:spike 69.5:stairs 73:gap 74:drop 78:spike 79.5:step 80.5:spike 81.5:drop 83:spike
84.5:spike 85.5:stairs 89:gap 90:drop 91:spike 93.5:orb 95:spike 96.5:gap 98:drop 99:spike 101.5:spike
103.5:spike 105.5:spike 106.75:step
; dip
111:gap
; drop 2
112.5:spike 113.5:drop 114.5:spike 116.5:chain2 119:spike 120.5:step 122.5:spike 123.75:gap 125.5:spike 126.5:drop
127.5:spike 130.25:orb 131.75:gap 133:spike 134.5:spike 135.5:drop 137.5:dl 139:spike 141.5:stairs 144.5:gap
146:drop 147.5:spike 149.5:spike 150.75:step 152.5:spike 154.75:gap 156:drop 157:spike 158.75:step 159.5:spike
162.5:gap 163.5:drop 164.5:spike 166.5:spike
; mid
168:spike 169.5:step 171:spike 173.25:gap 175.5:spike 177:drop 178.5:spike
; drop 3: kick on every x.5
180.5:chain3 183.5:step 184.5:spike 186.5:gap 188:drop 189.5:spike 191.25:step 193:spike 195:drop 195.75:spike
197.5:step 198.5:spike 200.5:gap 202:drop 203:spike 205.5:flip 207.5:spike 209:spike 210.25:orb 212.5:spike
214.5:gap 215.5:drop 217:spike 218.5:orb 221.5:gap 223:drop 225:spike 227.75:step 229:spike 231:gap 232:drop
233.5:spike 235:dr 237.5:chain2 241.25:step 242.5:spike 243.75:gap
; hi-hat break
245:drop 249:spike 253:spike 256.5:step 260.5:spike 264:gap 268.5:spike 270:drop 272.5:spike
; quiet, then the build
279:spike 281:spike 283:spike 285:step 286.5:spike 287.5:gap 289:spike 290.5:spike 292:drop 293:spike 294.5:step
295.5:spike 297:gap 299:spike 301.5:spike 302.5:drop 303.75:spike 307.5:spike 309.5:step 311:spike
; final
312.5:gap 314.5:drop 316.5:dr 319.25:step 320.5:spike 321.5:chain2 323.5:gap 325:drop 326.5:dl 328:spike
329.5:step 330.5:spike 331.5:gap 333.5:chain3 336.5:drop 337.5:dl 339:spike 340.5:spike 342.5:flip 345:step
346.5:spike 348:gap 350:drop 351.5:flip 353.5:chain3 358.5:step 359.75:spike 361:gap
"""

if __name__ == "__main__":
    build(SONG, STEPS)
