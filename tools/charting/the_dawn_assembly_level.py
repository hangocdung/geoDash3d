"""Builds the main chart of the_dawn_assembly (gameplay v3: terrain, orbs, pads) from musical patterns.

Usage: python tools/charting/the_dawn_assembly_level.py [out.chart.json]
Hand-placed on strong onsets of the_dawn_assembly with the shared patterns (terrain_patterns.py); other
songs use the automatic generator (terrain_level.py).
Related: docs/design/gameplay_v3.md, assets/music/the_dawn_assembly.chart.json
"""
import json
import sys

from terrain_patterns import Level, SpeedMap

OUT_PATH = "assets/music/the_dawn_assembly.chart.json"
END_BEAT = 116
SPEED_KEYS = [(0, 7.0), (48, 7.5), (80, 8.0)]


def build_level():
    level = Level(SpeedMap(SPEED_KEYS))
    # Intro: one idea at a time.
    level.spike(8)
    level.step(12, 1.5)
    level.drop(15)
    level.gap(17.5)
    level.spike(20)
    level.chain(22, 2)
    level.step(25.5, 1.5)
    level.step(28, 1.5)
    level.gap(29.5)
    level.drop(31)
    # Build: orbs, then a pad.
    level.spike(32)
    level.orb_up(33.5)
    level.spike(36)
    level.orb_up(37.5)
    level.drop(40, 2.0)
    level.spike(41.5)
    level.drop(43)
    level.spike(44)
    level.spike(46)
    level.pad(48)
    level.gap(50)
    level.spike(51.5)
    level.drop(53.5)
    level.spike(55)
    level.chain(57, 3)
    level.step(61, 1.5)
    level.step(62, 1.0)
    level.step(63, 1.0)
    # Verse: orb triplet over a pit, mixed terrain.
    level.drop(64)
    level.orb_triplet(65.5)
    level.spike(68)
    level.gap(69.5)
    level.drop(71)
    level.spike(72)
    level.orb_up(73.5)
    level.spike(76)
    level.step(77.5, 1.5)
    level.drop(79)
    level.spike(80)
    level.gap(81.5)
    level.pad(84)
    level.chain(85.5, 2)
    level.drop(88)
    level.orb_up(89.5)
    level.chain(92, 2)
    level.drop(94.5)
    # Chorus: fast stairs on the 0.75-beat motif.
    level.spike(96)
    level.stairs(98, 3)
    level.drop(101)
    level.stairs(102, 3)
    level.drop(105)
    level.floating_stairs(106, 3)
    level.drop(109)
    level.stairs(110, 3)
    return level


def build_chart():
    level = build_level()
    camera = [(-8, "front", 0), (-2, "side", 4), (32, "diagonal", 2), (48, "side", 2), (64, "side_high", 2),
              (80, "diagonal", 2), (92, "side", 2), (104, "side_far", 2), (112, "high", 4)]
    vfx = [(32, "flash"), (64, "shockwave"), (96, "flash"), (96, "shockwave"), (112, "burst")]
    events = list(level.events)
    events += [{"beat": beat, "type": "camera", "shot": shot, "blend_beats": blend} for beat, shot, blend in camera]
    events += [{"beat": beat, "type": "vfx", "name": name} for beat, name in vfx]
    events.sort(key=lambda event: (event["beat"], event["type"]))
    return {
        "version": 1,
        "title": "The Dawn Assembly",
        "artist": "Google Flow Music (AI)",
        "song": "res://assets/music/the_dawn_assembly.mp3",
        "offset_sec": 0.058,
        "end_beat": END_BEAT,
        "tempo": [{"beat": 0, "bpm": 120.0}],
        "speed": [{"beat": beat, "units_per_beat": rate} for beat, rate in SPEED_KEYS],
        "sections": [
            {"beat": -16, "name": "intro", "energy": 0.2}, {"beat": 32, "name": "build", "energy": 0.42},
            {"beat": 64, "name": "verse", "energy": 0.55}, {"beat": 92, "name": "lift", "energy": 0.7},
            {"beat": 96, "name": "chorus", "energy": 0.82}, {"beat": 112, "name": "outro", "energy": 0.4},
        ],
        "track": [
            {"beat": 0, "shape": "straight"}, {"beat": 26, "shape": "turn", "angle_deg": 30},
            {"beat": 34, "shape": "straight"}, {"beat": 52, "shape": "slope", "rise": 4},
            {"beat": 58, "shape": "straight"}, {"beat": 70, "shape": "turn", "angle_deg": -45},
            {"beat": 78, "shape": "straight"}, {"beat": 100, "shape": "turn", "angle_deg": 40},
            {"beat": 108, "shape": "straight"},
        ],
        "terrain": level.terrain,
        "events": events,
    }


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else OUT_PATH
    chart = build_chart()
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(chart, handle, indent="\t")
        handle.write("\n")
    taps = sum(1 for event in chart["events"] if event["type"] in ("jump", "orb"))
    print(f"wrote {out_path}: {taps} taps, {len(chart['terrain'])} terrain changes")


if __name__ == "__main__":
    main()
