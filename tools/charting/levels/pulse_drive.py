"""Pulse Drive, hand-charted on its standout hits only (122 BPM, steady): every tap lands on a hit clearly louder
than the quarter-beat slots around it, like the_dawn_assembly.

The hit on beat 2 of every bar carries the song. Intro 0-32: hat on 2, snares on 1 and 4 of the odd bars.
Groove 32-64: snare on 2 + kick on 2-and (orb). Verses 64-128: hats on 2 and 4, 3-and in the even bars.
Build 128-156: snares. Drops 160-224 / 256-324: snare on 2 and 3-and. Break 224-256: snares on 1, 2 and 4.
Outro 324-356: the loudest isolated hits of the song, densest taps.
Usage: python tools/charting/levels/pulse_drive.py   Related: tools/charting/handmade.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from handmade import build  # noqa: E402

SONG = {
    "id": "pulse_drive", "title": "Pulse Drive", "artist": "hdgstudio86", "bpm": 122.0, "offset": 0.5025,
    "end_beat": 356,
    "phases": [(0, "ocean", 7.0), (96, "indigo", 7.75), (160, "sunset", 8.5), (256, "ultraviolet", 9.25), (324, "void", 10.0)],
    "sections": [(-16, "intro", 0.25), (32, "groove", 0.5), (64, "verse", 0.45), (96, "verse2", 0.55),
                 (128, "build", 0.7), (156, "riser", 0.75), (160, "drop", 0.9), (224, "break", 0.6),
                 (256, "drop2", 1.0), (324, "outro", 0.7), (356, "end", 0.3)],
    "cameras": [(-8, "front", 0), (-2, "side", 4), (32, "diagonal", 2), (64, "side", 2), (96, "side_high", 2),
                (128, "diagonal", 2), (160, "side_far", 2), (192, "diagonal", 2), (224, "side", 4),
                (256, "side_far", 2), (288, "side_high", 2), (324, "diagonal", 2), (344, "high", 4)],
    "track": [(0, {"shape": "straight"}), (40, {"shape": "turn", "angle_deg": 30}), (48, {"shape": "straight"}),
              (108, {"shape": "slope", "rise": 4}), (113, {"shape": "straight"}),
              (224, {"shape": "turn", "angle_deg": -35}), (232, {"shape": "straight"}),
              (322, {"shape": "turn", "angle_deg": 30}), (328, {"shape": "straight"})],
    "vfx": [(32, "flash"), (96, "shockwave"), (160, "flash"), (160, "shockwave"), (224, "shockwave"),
            (256, "flash"), (256, "shockwave"), (324, "flash"), (356, "burst")],
}

STEPS = """
; intro: hat on 2 every bar, snares on 1 and 4 of the odd bars
9:spike 13:step 15:spike 16:drop 17:spike 21:spike 23:gap 25:spike 28:spike 29:trip 31:spike 32:drop
; groove: snare on 2 + kick on 2-and (orb), kicks on 3-and
33:spike 37:orb 39:drop 41:spike 45:orb 47:drop 49:spike 50.5:step 52:spike 53:orb 55:drop 57:spike 61:orb
63:drop
; verse: hats on 2 and 4, 3-and in the even bars
69:spike 71:dl 73:spike 74.5:gap 76:chain2 81:flip 84:chain2 89:flip 93:dr
; verse 2
101:spike 103:gap 105:step 106.5:spike 107.5:drop 113:spike 116:chain2 121:dl 122.5:spike
; build: snares, then the riser (2-and / 3 / 4)
130:spike 133:spike 135:step 137:drop 138:spike 141:chain3 144.5:spike 146:spike 149:spike 151:spike 155:spike
157.5:orb 159:spike 160:drop
; drop: snare on 2 of every bar and on 3-and of the even bars
165:spike 169:step 170.5:spike 172:drop 173:spike 177:dl 178.5:spike 181:spike 185:step 186.5:spike
187.5:spike 189:orb 191:drop 193:dr 194.5:spike 197:spike 201:spike 202.5:spike 203.5:spike 205:flip
209:spike 210.5:step 212:drop 213:spike 217:chain2 219.5:spike
; break: snares on 1, 2 and 4
228:spike 231:spike 233:gap 234.5:spike 236:chain2 239:dl 244:step 245:spike 247:spike 248:drop 249:spike
250.5:spike 252:chain2
; drop 2: same motif, denser
257:chain2 261:spike 262.5:spike 265:dl 269:spike 270.5:spike 273:flip 277:spike 278.5:step 281:spike
282:drop 285:spike 286.5:spike 287.5:orb 289:spike 290:drop 293:spike 294.5:spike 297:flip 301:spike
302.5:spike 303.5:step 305:spike 306:drop 309:spike 310.5:spike 313:dr 317:chain2 319.5:spike 321:spike
; outro: the loudest isolated hits
326.5:spike 328:step 329:spike 330:drop 331:spike 333:dl 334.5:spike 336:spike 337:orb 339:drop 341:spike
342.5:gap 344:chain2 347:dr 349:spike 350.5:spike 352:chain2
"""

if __name__ == "__main__":
    build(SONG, STEPS)
