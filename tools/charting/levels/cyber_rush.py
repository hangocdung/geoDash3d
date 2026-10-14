"""Cyber Rush, hand-charted phrase by phrase on its drum hits (135 BPM, steady).

Intro 0-56: clap on every beat, taps on beats. Drop 1 (60-124): kick 0/0.75/3.5, snare 2/3. Break 124-172.
Drop 2 (172-240): syncopated hit on 2.75 then 3.25 -> jump + orb. Break 240-284. Final 284-352: densest.
Usage: python tools/charting/levels/cyber_rush.py   Related: tools/charting/handmade.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from handmade import build  # noqa: E402

SONG = {
    "id": "cyber_rush", "title": "Cyber Rush", "artist": "Unknown", "bpm": 135.0, "offset": 1.767, "end_beat": 352,
    "speed": [(0, 7.0), (124, 7.5), (172, 8.0), (284, 8.5)],
    "sections": [(-16, "intro", 0.5), (60, "drop", 0.85), (124, "break", 0.25), (172, "drop2", 0.9),
                 (240, "break2", 0.3), (284, "final", 1.0), (352, "outro", 0.3)],
    "cameras": [(-8, "front", 0), (-2, "side", 4), (60, "side_far", 2), (124, "side", 4), (172, "diagonal", 2),
                (204, "side_high", 2), (240, "side", 4), (284, "diagonal", 2), (316, "side_high", 2), (340, "high", 3)],
    "track": [(0, {"shape": "straight"}), (124, {"shape": "turn", "angle_deg": 30}), (132, {"shape": "straight"}),
              (240, {"shape": "turn", "angle_deg": -35}), (248, {"shape": "straight"}),
              (296, {"shape": "slope", "rise": 4}), (304, {"shape": "straight"})],
    "vfx": [(60, "flash"), (60, "shockwave"), (172, "flash"), (172, "shockwave"), (284, "flash"), (284, "shockwave"),
            (352, "burst")],
}

STEPS = """
; intro: one tap a bar, then pairs on the claps (kept light: the level ramps up)
8:spike 12:spike 16:step 19:drop 20:gap 24:spike 28:step 30:gap 32:drop
36:spike 38:spike 40:step 42:spike 43:drop 44:gap 48:step 50:gap 52:drop 54:spike
; pad on the pre-drop hit, back down for the drop
56:pad 59:drop
; drop 1: downbeats, kick on 0.75, snares on 2 and 3
60:spike 62:spike 63:step 64:spike 66:gap 67:drop 68:spike 70:spike 71:step 72.75:orb 75:gap 76:drop
78:chain2 80:step 80.75:step 82:spike 83:drop 85:spike 87:spike
88:step 88.75:step 91.5:gap 93:drop 94:spike 95.5:spike
96.75:step 98:spike 99.5:drop 101:chain3 104:step 104.75:step 106.25:gap 108:drop 110:spike 111.5:spike
114:step 116.75:spike 118:gap 119:drop 120:spike 122.5:spike
; break: sparse downbeats, a pad on the big clap at 156
128:spike 132.75:step 136.75:spike 140:drop 148:gap 152:step 156:pad 160:drop 166:spike 172.75:spike 174.75:spike
; drop 2: downbeat, then jump on 2.75 + orb on 3.25
176:spike 178.75:orb 182:gap 183:drop 184:spike 186.75:orb 189:spike 190.5:spike 191.5:drop
194:flip 197.25:orb 200:spike 202.25:step 204:spike 206:drop 207:spike
208:step 210.75:orb 213.5:gap 214.5:spike 215.5:drop 218.75:orb 221.25:step 223:gap 224:drop
226:dl 230:dr 232:spike 234.75:orb 237.5:gap 239:drop
; break 2
248:gap 256:step 260:drop 264:spike 269:spike 272:gap 278:spike 280:spike 283.75:step
; final: densest; stairs on 294 / 294.75 / 295.5
284.75:spike 286.25:step 287:step 288:gap 290:spike 291:drop 292.75:spike 294:stairs 297:gap 298:drop
302:flip 304:spike 306:spike 308.5:orb 310.5:drop 312:spike 314.75:dr 318:spike 319.5:step 321.5:orb
323.5:gap 324.5:drop 326:spike 327.25:step 328:step 330:gap 332:drop 332.75:spike 334:spike 335.5:spike
338:flip 342:spike 343.75:step 346:gap 347.5:spike 350:spike
"""

if __name__ == "__main__":
    build(SONG, STEPS)
