"""Tribal Battle Awakening (Take 2), hand-charted on its tresillo groove (150.02 BPM, steady).

Every bar accents beats 0, 1.5 and 3 (3+3+2): quiet parts take the first two, loud parts all three.
Intro 0-64, groove 64-128, drop 128-184, verse 184-256, drop 2 256-312, break 312-352, final 352-408, outro.
Usage: python tools/charting/levels/tribal_battle_awakening_take2.py   Related: tools/charting/handmade.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from handmade import build  # noqa: E402

SONG = {
    "id": "tribal_battle_awakening_take2", "audio": "tribal_battle_awakening_take2",
    "title": "Tribal Battle Awakening 2 (Beat)", "artist": "Unknown", "bpm": 150.02, "offset": 0.082,
    "end_beat": 440,
    "phases": [(0, "ocean", 7.0), (128, "sunset", 8.0), (256, "ultraviolet", 8.75), (352, "ember", 9.5)],
    "sections": [(-16, "intro", 0.5), (64, "groove", 0.7), (128, "drop", 0.9), (184, "verse", 0.65),
                 (256, "drop2", 0.95), (312, "break", 0.25), (352, "final", 1.0), (408, "outro", 0.3)],
    "cameras": [(-8, "front", 0), (-2, "side", 4), (64, "side_far", 2), (128, "diagonal", 2), (184, "side", 4),
                (256, "side_far", 2), (284, "diagonal", 2), (312, "side", 4), (352, "diagonal", 2),
                (380, "side_high", 2), (408, "high", 3)],
    "track": [(0, {"shape": "straight"}), (80, {"shape": "wave", "amplitude": 2, "count": 2}),
              (96, {"shape": "straight"}), (128, {"shape": "loop", "lateral": 7}), (140, {"shape": "straight"}),
              (160, {"shape": "roll", "roll_deg": 360}), (168, {"shape": "straight"}),
              (184, {"shape": "turn", "angle_deg": 30, "bank_deg": 20}), (192, {"shape": "straight"}),
              (200, {"shape": "helix", "angle_deg": 360, "rise": 18}), (216, {"shape": "straight"}),
              (256, {"shape": "loop", "lateral": -7}), (268, {"shape": "straight"}),
              (312, {"shape": "turn", "angle_deg": -35, "bank_deg": 22}), (320, {"shape": "straight"}),
              (328, {"shape": "roll", "roll_deg": -360}), (336, {"shape": "straight"}),
              (352, {"shape": "loop", "lateral": 7}), (364, {"shape": "straight"}),
              (408, {"shape": "turn", "angle_deg": 40, "bank_deg": 25}), (416, {"shape": "straight"})],
    "vfx": [(128, "flash"), (128, "shockwave"), (256, "flash"), (256, "shockwave"), (352, "flash"),
            (352, "shockwave"), (408, "burst")],
}

STEPS = """
; intro: one hit a bar, then bar heads 0 and 1.5
8:spike 12:spike 16:spike 20:spike 24:spike 28:spike 29.5:step 31:drop
32:spike 33.5:spike 36:spike 40:spike 41.5:orb 44:spike 47:drop 48:spike 49.5:spike 52:spike 56:spike 57.5:spike
60:step 61.5:step 63:drop
; groove: bar heads, the third hit on phrase ends
64:spike 65.5:spike 68:step 71:gap 72:spike 73.5:spike 75:step 77:drop 80:spike 81.5:spike 84:spike 88:spike
89.5:orb 92:spike 95:drop 96:spike 97.5:spike 100:dl 104:spike 105.5:spike 107:step 109.5:spike 112:spike
113.5:spike 115:orb 117.5:spike 119:orb 121:drop 124:spike 125.5:spike
; drop: all three hits, every bar
128:spike 129.5:spike 131:spike 132:step 133.5:spike 135:gap 136:spike 137.5:orb 140:spike 141.5:spike 142.5:drop
144:spike 145.5:spike 147:spike 148:dl 149.5:spike 151:spike 152:spike 153.5:spike 155:spike 156:flip 159:spike
160:spike 161.5:spike 163:spike 164:step 165.5:step 167:spike 168:spike 169.5:orb 172:spike 173:drop 175:spike
176:spike 177.5:spike 179:spike 180:dr 182:spike 183:spike
; verse: bar heads again
184:spike 185.5:spike 188:spike 189.5:step 191:drop 192:spike 193.5:spike 196:spike 197.5:spike 200:spike
201.5:step 203:spike 204:spike 205.5:spike 207:drop
208:spike 209.5:spike 212:spike 213.5:spike 216:gap 217.5:spike 220:step 221.5:step 223:drop
224:spike 225.5:spike 228:spike 229.5:spike 232:dl 235:spike 236:spike 237.5:orb 240:spike 241.5:spike 243:drop
244:spike 245.5:spike 248:spike 249.5:spike 251:spike 252:step 253.5:step 255:drop
; drop 2
256:spike 257.5:spike 259:spike 260:spike 261.5:spike 263:spike 264:step 265.5:spike 267:gap 268:spike
269.5:orb 272:spike 273.5:spike 274.5:drop 276:spike 277.5:spike 279:spike
280:dl 281.5:spike 283:spike 284:spike 285.5:spike 287:spike 288:flip 291:spike 292:spike 293.5:spike 295:spike
296:step 297.5:step 299:spike 300:spike 301.5:orb 304:spike 305:drop 307:spike 308:spike 309.5:spike 311:spike
; break: one hit a bar, two as it builds back
316:spike 320:spike 324:spike 328:spike 332:spike 336:spike 337.5:spike 340:step 341.5:spike 344:spike 345.5:spike 348:spike 349.5:spike 350.5:drop
; final
352:spike 353.5:spike 355:spike 356:step 357.5:spike 359:gap 360:spike 361.5:orb 364:spike 365.5:spike
366.5:drop 368:spike 369.5:spike 371:spike 372:dl 373.5:spike 375:spike 376:flip 379:spike 380:spike
381.5:spike 383:spike 384:step 385.5:spike 387:step 388:spike 389.5:orb 392:spike 393:drop 395:spike 396:spike
397.5:trip 400:spike 401:drop 403:spike 404:spike 405.5:spike 407:spike
; outro
412:spike 416:spike 420:spike 424:spike
"""

if __name__ == "__main__":
    build(SONG, STEPS)
