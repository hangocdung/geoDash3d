"""Tribal Battle Awakening, hand-charted on its beat (150 BPM, steady; the analysis said 100 = a 2:3 mis-lock).

Half-time drums: the big hits sit on phrase beats 6, 8 and 13.5-14, with drum fills before phrase ends.
Intro 0-48, build 48-96, drop 96-144, verse 144-192, drop 2 192-240, bridge 240-288, final 288-384, outro.
Usage: python tools/charting/levels/tribal_battle_awakening.py   Related: tools/charting/handmade.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from handmade import build  # noqa: E402

SONG = {
    "id": "tribal_battle_awakening", "audio": "tribal_battle_awakening", "title": "Tribal Battle Awakening (Beat)",
    "artist": "Unknown", "bpm": 150.0, "offset": 0.786, "end_beat": 432,
    "phases": [(0, "indigo", 7.0), (96, "sunset", 8.0), (192, "aurora", 8.75), (288, "ember", 9.5)],
    "sections": [(-16, "intro", 0.4), (48, "build", 0.6), (96, "drop", 0.85), (144, "verse", 0.6),
                 (192, "drop2", 0.85), (240, "bridge", 0.7), (288, "final", 1.0), (384, "outro", 0.35)],
    "cameras": [(-8, "front", 0), (-2, "side", 4), (96, "side_far", 2), (144, "side", 4), (192, "diagonal", 2),
                (240, "side_high", 2), (288, "diagonal", 2), (336, "side_high", 2), (384, "high", 3)],
    "track": [(0, {"shape": "straight"}), (144, {"shape": "turn", "angle_deg": 30}), (152, {"shape": "straight"}),
              (240, {"shape": "turn", "angle_deg": -35}), (248, {"shape": "straight"}),
              (384, {"shape": "turn", "angle_deg": 40}), (392, {"shape": "straight"})],
    "vfx": [(96, "flash"), (96, "shockwave"), (192, "flash"), (192, "shockwave"), (288, "flash"),
            (288, "shockwave"), (384, "burst")],
}

STEPS = """
; intro: the hits on 6, 8 and 14
8:spike 14:spike 22:spike 24:spike 30:spike 32:spike 38:spike 42:spike 46:step
; build
48:drop 54:spike 56:spike 62:step 64:drop 70:spike 72:spike 77.5:orb 80:spike 86:spike 88:spike 91.5:orb
93:drop 94:spike
; drop: fills on the half beats before each phrase end
100:spike 102:spike 108:step 111.5:orb 113:drop 116:chain3 120:spike 124:step 127.5:orb
129.5:drop 132:spike 133:orb 136:spike 138:step 140:spike 141:orb 142.5:drop
; verse
149.5:orb 151:drop 154:spike 158:spike 160:spike 162:spike 166:spike 168:step 170:spike 174:spike
177.5:spike 184:spike 188:step 189.5:spike 190.5:drop
; drop 2: a wall of sound, so the half-time pulse
192:spike 196:spike 200:dl 204:spike 206:spike 208:spike 212:spike 216:dr 220:spike 222:step
223:drop 224:spike 228:spike 232:flip 235:spike 237.5:orb 239:drop
; bridge
241.5:spike 244:spike 246:spike 248:step 252:orb 254:drop 256:spike 260:orb 262:spike 264:chain2
270.5:step 272:drop 276:spike 278:spike 286.5:orb
; final: fills everywhere
289:spike 292:orb 294:drop 298:spike 300.5:spike 301.5:orb 304:spike 305:step 307:drop 309:spike 312:spike
314:spike 316:trip 318:spike 319:drop 322:orb 324:chain2 328:spike 330:step 332:drop 340:spike 342:spike
344:dl 347:spike 348.5:spike 350.5:spike 352:orb 354:drop 356:chain2 360:flip 365:spike 368:spike 370:spike
372:step 375:spike 378:spike 380:trip 382:spike 383:drop
; outro
393:spike 397.5:orb 401:spike 413.5:orb 417:spike 427:spike
"""

if __name__ == "__main__":
    build(SONG, STEPS)
