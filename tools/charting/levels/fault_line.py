"""Fault Line, hand-charted on its standout hits only (128 BPM, steady): every tap lands on a hit clearly louder
than the quarter-beat slots around it, like the_dawn_assembly. Silent bars stay empty.

Intro 0-36: hits on beats 2 and 4 of every other bar. Verses 36-136: one big hit on beat 4 of each bar, plus a
kick + hat pair on 1 and 1-and (orb) in the odd bars. Bridge 136-168: snares on the downbeats. Riser 168: three
hits half a beat apart (orb triplet). Chorus 172-268 is a dense wall where only the clap on beat 4 stands out,
so it is one tap a bar. Outro 268-332: clearest motif (2, 4, then 1 + 1-and), densest taps.
Usage: python tools/charting/levels/fault_line.py   Related: tools/charting/handmade.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from handmade import build  # noqa: E402

SONG = {
    "id": "fault_line", "title": "Fault Line", "artist": "hdgstudio86", "bpm": 128.0, "offset": 0.448,
    "end_beat": 332,
    "speed": [(0, 7.0), (100, 7.5), (172, 8.0), (268, 8.5), (300, 9.0)],
    "sections": [(-16, "intro", 0.25), (36, "verse", 0.45), (68, "verse2", 0.5), (100, "verse3", 0.55),
                 (136, "bridge", 0.7), (168, "riser", 0.75), (172, "chorus", 0.9), (268, "outro", 0.6),
                 (332, "end", 0.3)],
    "cameras": [(-8, "front", 0), (-2, "side", 4), (36, "diagonal", 2), (68, "side", 2), (100, "side_high", 2),
                (136, "diagonal", 2), (172, "side_far", 2), (220, "diagonal", 2), (268, "side", 4),
                (300, "side_high", 2), (324, "high", 4)],
    "track": [(0, {"shape": "straight"}), (52, {"shape": "turn", "angle_deg": 30}), (60, {"shape": "straight"}),
              (112, {"shape": "slope", "rise": 4}), (120, {"shape": "straight"}),
              (196, {"shape": "turn", "angle_deg": -35}), (204, {"shape": "straight"}),
              (292, {"shape": "turn", "angle_deg": 30}), (300, {"shape": "straight"})],
    "vfx": [(36, "flash"), (100, "shockwave"), (136, "flash"), (172, "flash"), (172, "shockwave"),
            (220, "shockwave"), (268, "flash"), (332, "burst")],
}

STEPS = """
; intro: beat 2 / beat 4 hits of the even bars, the odd bars are silent
9:spike 11:orb 13:drop 17:spike 19:spike 25:spike 27:orb 29:drop 30.5:spike 33:chain3
; verse: big hit on beat 4, hats on 2 and 3
37:spike 39:step 43:spike 45:drop 50:chain2 52:orb 55:spike 56:drop 59:spike 64.5:orb
; verse 2: kick + hat on 1 / 1-and (orb), then 3 and 4
68:orb 70:chain2 72:drop 75:spike 76:orb 78:chain2 80:drop 83:spike 84:orb 86:step 87:spike 88:drop
89:gap 91:spike 92:orb 94:spike 95:drop 99:spike
; verse 3: same motif, lane dodges and flips on the lone hits
100:orb 102:chain2 104:drop 107:dl 110:spike 113:spike 115:spike 116:orb 118:chain2 120:drop 121:spike
123:flip 126:spike 129:flip
; bridge: snares on the downbeats
136:spike 141.5:spike 143:chain3 148:spike 149.5:spike 152:chain2 154.5:step 156:spike 157:drop 161:spike
163:chain2
; riser: three hits half a beat apart
170.5:trip
; chorus: only the clap on beat 4 stands out
173:spike 174:drop 175:spike 179:step 181:drop 183:gap 187:dl 191:spike 195:flip 197.5:spike 199:spike
201.5:spike 203:spike 207:dr 211:step 213:drop 215:gap 219:flip 223:spike 227:dl 231:step 233:drop 235:spike
239:flip 243:spike 247:dr 251:step 253:drop 255:gap 259:flip 263:spike 267:dl
; outro: beat 2, beat 4, then kick + hat on 1 / 1-and of the next bar
271:spike 272:orb 274:drop 277:flip 279:spike 280:orb 282:drop 285:dl 287:spike 288:orb 290:drop
293:spike 295:spike 296:orb 298:drop 301:flip 303:spike 304:orb 306:drop 309:dr 311:spike 312:orb 314:drop
317:flip 319:spike 320:orb 322:drop 325:dl 327:spike 328:orb 330:drop
"""

if __name__ == "__main__":
    build(SONG, STEPS)
