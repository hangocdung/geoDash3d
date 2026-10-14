"""Builds the main chart of the_dawn_assembly (gameplay v3: terrain, orbs, pads) from musical patterns.

Usage: python tools/charting/the_dawn_assembly_level.py [out.chart.json]
Jump orbs sit at an arc's apex, where tap timing barely changes the height (forgiving).
Every pattern places taps on strong onsets of the_dawn_assembly and shapes the ground around them so the
timing tolerance is symmetric. Arc numbers mirror GameplayConfig.create_default(): jump and orb last 1 beat
and peak at 2.0 (gravity 16 units/beat^2), a pad launch lasts 1.5 beats and peaks at 4.5.
Related: docs/design/gameplay_v3.md, assets/music/the_dawn_assembly.chart.json
"""
import json
import sys

OUT_PATH = "assets/music/the_dawn_assembly.chart.json"
END_BEAT = 116
SPEED_KEYS = [(0, 7.0), (48, 7.5), (80, 8.0)]
PLAYER_HALF_LENGTH = 0.38
PAD_HALF_LENGTH = 0.6
PAD_RISE = 4.0
ORB_RISE = 2.0


def speed_at(beat):
    rate = SPEED_KEYS[0][1]
    for key_beat, key_rate in SPEED_KEYS:
        if beat >= key_beat:
            rate = key_rate
    return rate


def distance_at(beat):
    distance = 0.0
    for index, (key_beat, rate) in enumerate(SPEED_KEYS):
        next_beat = SPEED_KEYS[index + 1][0] if index + 1 < len(SPEED_KEYS) else float("inf")
        if beat <= key_beat:
            break
        distance += (min(beat, next_beat) - key_beat) * rate
    return distance


def beat_at_distance(distance):
    low, high = -16.0, END_BEAT + 64.0
    for _ in range(80):
        middle = (low + high) / 2.0
        if distance_at(middle) < distance:
            low = middle
        else:
            high = middle
    return (low + high) / 2.0


class Level:
    def __init__(self):
        self.ground = 0.0
        self.events = []
        self.terrain = []

    def _set_ground(self, beat, height):
        self.terrain.append({"beat": round(beat, 4), "height": round(height, 3)})
        self.ground = height

    def _edge(self, front_beat):
        """Beat of a ground edge that the player's front reaches at `front_beat`."""
        return front_beat + PLAYER_HALF_LENGTH / speed_at(front_beat)

    def _jump(self, beat, hazard="none"):
        event = {"beat": beat, "type": "jump"}
        if hazard == "none":
            event["hazard"] = "none"
        self.events.append(event)

    def spike(self, beat):
        """Single jump over a spike standing on the current ground."""
        self._jump(beat, "spike")

    def chain(self, beat, count):
        """Spikes one beat apart: jump again the moment you land."""
        for index in range(count):
            self.spike(beat + index)

    def step(self, beat, rise):
        """Jump onto a ledge `rise` higher; its edge sits under the apex (rise <= 1.5)."""
        self._jump(beat)
        self._set_ground(self._edge(beat + 0.5), self.ground + rise)

    def stairs(self, beat, count, spacing=0.75, rise=1.5):
        """Fast stairs: each +1.5 step lands exactly 0.75 beat after take-off, on the next tap."""
        for index in range(count):
            self.step(beat + index * spacing, rise)

    def drop(self, beat, height=0.0):
        """Run off a ledge down to `height` (no tap)."""
        self._set_ground(beat, height)

    def gap(self, beat, width=0.5):
        """Jump over a hole centred under the apex."""
        self._jump(beat)
        level = self.ground
        self.terrain.append({"beat": round(beat + 0.5 - width / 2.0, 4), "gap": True})
        self._set_ground(beat + 0.5 + width / 2.0, level)

    def orb_up(self, beat):
        """Jump, tap the orb at the apex, land on a platform 2 higher one beat later."""
        self._jump(beat)
        self.events.append({"beat": beat + 0.5, "type": "orb"})
        self._set_ground(beat + 1.0, self.ground + ORB_RISE)

    def orb_triplet(self, beat):
        """Jump + two orbs half a beat apart over a pit, climbing 4 units onto a platform."""
        self._jump(beat)
        level = self.ground
        self.events.append({"beat": beat + 0.5, "type": "orb"})
        self.events.append({"beat": beat + 1.0, "type": "orb"})
        self.terrain.append({"beat": round(beat + 0.3, 4), "gap": True})
        self._set_ground(beat + 1.5, level + 2.0 * ORB_RISE)

    def floating_stairs(self, beat, count, spacing=0.75, rise=1.5):
        """Fast stairs on floating blocks: the same rhythm, but a missed step falls through the gaps."""
        base = self.ground
        for index in range(count):
            cue = beat + index * spacing
            self._jump(cue)
            self._set_ground(self._edge(cue + 0.5), base + rise * (index + 1))
            if index + 1 < count:
                # The block ends 0.2 beat after the next take-off (late-tap margin), then a hole.
                self.terrain.append({"beat": round(cue + spacing + 0.2, 4), "gap": True})

    def pad(self, beat):
        """Jump pad (no tap): the launch peaks 4.5 up and lands on a platform 4 higher."""
        self.events.append({"beat": beat, "type": "pad"})
        trigger = beat_at_distance(distance_at(beat) - PAD_HALF_LENGTH - PLAYER_HALF_LENGTH)
        self._set_ground(trigger + 0.75, self.ground + PAD_RISE)


def build_level():
    level = Level()
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
