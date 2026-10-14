"""Cyber Rush (Take 2), hand-charted phrase by phrase on its drum hits (140 BPM, steady).

Clap accents on beats 1 and 3 all song long; kick accents on 2.75 and in rolls. Intro 0-52, break 52-64,
drop 64-124, hi-hat verse 124-188, long break 188-264, drop 2 264-320, break 320-332, final 332-388.
Usage: python tools/charting/levels/cyber_rush_take2.py   Related: tools/charting/handmade.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from handmade import build  # noqa: E402

SONG = {
    "id": "cyber_rush_take2", "title": "Cyber Rush (Take 2)", "artist": "Unknown", "bpm": 139.98, "offset": 1.324,
    "end_beat": 388,
    "phases": [(0, "ocean", 7.0), (64, "aurora", 7.75), (188, "sunset", 8.5), (264, "ultraviolet", 9.25), (332, "void", 10.0)],
    "sections": [(-16, "intro", 0.7), (52, "break", 0.3), (64, "drop", 0.9), (124, "verse", 0.7),
                 (188, "break2", 0.25), (264, "drop2", 0.95), (320, "break3", 0.35), (332, "final", 1.0),
                 (388, "outro", 0.3)],
    "cameras": [(-8, "front", 0), (-2, "side", 4), (64, "side_far", 2), (124, "diagonal", 2), (156, "side_high", 2),
                (188, "side", 4), (264, "side_far", 2), (296, "diagonal", 2), (320, "side", 3), (332, "diagonal", 2),
                (360, "side_high", 2)],
    "track": [(0, {"shape": "straight"}), (124, {"shape": "turn", "angle_deg": 30}), (132, {"shape": "straight"}),
              (188, {"shape": "turn", "angle_deg": -35}), (196, {"shape": "straight"}),
              (320, {"shape": "turn", "angle_deg": 40}), (328, {"shape": "straight"})],
    "vfx": [(64, "flash"), (64, "shockwave"), (264, "flash"), (264, "shockwave"), (332, "flash"),
            (332, "shockwave"), (388, "burst")],
}

STEPS = """
; intro: claps on 1 and 3, one idea at a time
5:spike 9:spike 13:step 15:gap 16:drop 17:spike 19:spike 21:step 23:gap 24:drop 25:spike 27:spike
28.5:orb 31:gap 32:drop 35:spike 37:spike 39:step 41:gap 42:drop 43:spike 45:spike 47:step 49:spike 51:gap
; break
52.5:drop 57:spike 61:spike 63:step
; drop: claps on 1 and 3, kick accents on 2.75
64:spike 66.75:step 69:spike 71:gap 72:drop 73:spike 74.75:step 77:spike 79:gap 80:drop 81:spike 82.75:step
85:spike 87:gap 88:drop 89:chain3 92:spike 95.25:step 96:step 97:gap 98.75:spike 100:drop 101:spike 103:spike
104.75:step 106.75:spike 108:gap 110:drop 111:spike 113:spike 114:step 116:spike 119:gap 120:drop 121:spike 122.5:spike
; hi-hat verse: kick accents
128:spike 130:spike 132.5:step 134:spike 136.5:gap 139:drop 140:dl 142:spike 145:spike 147:spike 148.5:orb 151:gap
152:drop 153:spike 154:step 159.25:step 160:gap 162:spike 163:drop 165:spike 168:flip 170:spike 171.75:step
174:spike 175:gap 177:spike 178:step 180.5:spike 182:drop 183.25:spike 185.25:spike 187.25:spike
; long break: one kick every two bars
193:spike 201.25:spike 210.5:gap 214:step 218.5:spike 221.25:drop 222.75:spike 225:spike 229.25:gap 232:spike
237.5:step 241.5:spike 243.75:spike 245.5:gap 248:drop 250.5:spike 257:spike 263:step
; drop 2: clap runs
265:spike 267:gap 268:drop 269:chain3 273:spike 274:step 276:spike 277:step 278:gap 279:drop 280:spike 281:step
283:gap 284.5:orb 286:spike 287:gap 288:drop 289.75:spike 291:spike 292:step 293:spike 294.25:step 295.75:spike
297:gap 298:drop 299:spike 301:spike 302:dr 304:spike 305:step 307:spike 308:drop 310:flip 313:spike 315.5:spike
; break 3
319:spike 326:spike 327.5:step
; final: densest
330:spike 331:gap 332:spike 333:orb 335:gap 336:drop 337:spike 339:spike 340:step 341:step 343:gap 344:drop
345:spike 347:spike 348:step 348.75:step 349.75:gap 350.75:spike 352:drop 353:spike 354:step 356:spike 357:gap
358:drop 359.75:spike 361:spike 362:flip 364:spike 365:step 367:spike 368:drop 369:spike 370:dl 372:spike
373:step 374:step 374.75:gap 377:spike 378:drop 380:chain3 383:spike 385:chain3
"""

if __name__ == "__main__":
    build(SONG, STEPS)
