"""Terrain level patterns shared by hand-written levels and the automatic generator (gameplay v3).

Each pattern places taps (chart events) and ground changes relative to the current ground so the timing
tolerance is symmetric. Arc numbers mirror GameplayConfig.create_default(): jump and orb last 1 beat and
peak at 2.0 (gravity 16 units/beat^2), a pad launch lasts 1.5 beats and peaks at 4.5. Jump orbs sit at an
arc's apex, where tap timing barely changes the height (forgiving).
Related: tools/charting/terrain_level.py, tools/charting/the_dawn_assembly_level.py, docs/design/gameplay_v3.md
"""
import math

PLAYER_HALF_LENGTH = 0.38
PAD_HALF_LENGTH = 0.6
PAD_RISE = 4.0
ORB_RISE = 2.0
GRAVITY = 16.0
# Spiked ceiling hazard (GameplayConfig._ceiling): half its length, and the beat after the dive tap where its
# near edge sits (a plain jump arc is still 1+ unit up there, a dive has landed ~0.15 beat after the tap).
CEILING_HALF_LENGTH = 2.4
CEILING_EDGE_AFTER_DIVE = 0.4


class SpeedMap:
    """Piecewise-constant run speed: [(beat, units_per_beat), ...] sorted by beat."""

    def __init__(self, keys):
        self.keys = keys

    def speed_at(self, beat):
        rate = self.keys[0][1]
        for key_beat, key_rate in self.keys:
            if beat >= key_beat:
                rate = key_rate
        return rate

    def distance_at(self, beat):
        distance = 0.0
        for index, (key_beat, rate) in enumerate(self.keys):
            next_beat = self.keys[index + 1][0] if index + 1 < len(self.keys) else float("inf")
            if beat <= key_beat:
                break
            distance += (min(beat, next_beat) - key_beat) * rate
        return distance

    def beat_at_distance(self, distance):
        low, high = -64.0, 4096.0
        for _ in range(80):
            middle = (low + high) / 2.0
            if self.distance_at(middle) < distance:
                low = middle
            else:
                high = middle
        return (low + high) / 2.0


def fall_beats(height):
    """Beats to fall `height` units from rest."""
    return math.sqrt(2.0 * max(height, 0.0) / GRAVITY)


class Level:
    def __init__(self, speed_map):
        self.speed = speed_map
        self.ground = 0.0
        self.events = []
        self.terrain = []

    def _set_ground(self, beat, height):
        self.terrain.append({"beat": round(beat, 4), "height": round(height, 3)})
        self.ground = height

    def _edge(self, front_beat):
        """Beat of a ground edge that the player's front reaches at `front_beat`."""
        return front_beat + PLAYER_HALF_LENGTH / self.speed.speed_at(front_beat)

    def _jump(self, beat, hazard="none"):
        event = {"beat": beat, "type": "jump"}
        if hazard != "spike":
            event["hazard"] = hazard
        self.events.append(event)

    def spike(self, beat, hazard="spike"):
        """Single jump over a spike (or `hazard`: spike_double, spike_triple, saw) standing on the current ground."""
        self._jump(beat, hazard)

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

    def big_orb(self, beat):
        """Jump, tap the big orb at the apex: a 1.5-beat high arc over a pit onto a platform 2 higher (lands +2.0)."""
        self._jump(beat)
        level = self.ground
        self.events.append({"beat": beat + 0.5, "type": "orb_big"})
        self.terrain.append({"beat": round(beat + 0.3, 4), "gap": True})
        self._set_ground(beat + 1.0, level + ORB_RISE)

    def dive(self, beat):
        """Jump a small hole, tap the dive orb at the apex and slam down under a spiked ceiling.
        Returns the beat at which the ceiling's far edge has passed the player."""
        self._jump(beat)
        level = self.ground
        self.terrain.append({"beat": round(beat + 0.15, 4), "gap": True})
        self._set_ground(beat + 0.4, level)
        dive_beat = beat + 0.5
        self.events.append({"beat": dive_beat, "type": "orb_drop"})
        speed = self.speed.speed_at(dive_beat)
        edge = dive_beat + CEILING_EDGE_AFTER_DIVE
        self.events.append({"beat": round(edge + CEILING_HALF_LENGTH / speed, 4), "type": "hazard",
                            "hazard": "ceiling"})
        return edge + 2.0 * CEILING_HALF_LENGTH / speed + PLAYER_HALF_LENGTH / speed

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

    def pad_trigger(self, beat):
        """Beat at which the player's feet touch a pad placed at `beat`."""
        return self.speed.beat_at_distance(self.speed.distance_at(beat) - PAD_HALF_LENGTH - PLAYER_HALF_LENGTH)

    def pad(self, beat):
        """Jump pad (no tap): the launch peaks 4.5 up and lands on a platform 4 higher."""
        self.events.append({"beat": beat, "type": "pad"})
        self._set_ground(self.pad_trigger(beat) + 0.75, self.ground + PAD_RISE)

    def dodge(self, beat, side):
        """Two-lane wall: slide into the free lane (`side` = "left" / "right"). Needs flat road at 0."""
        self.events.append({"beat": beat, "type": "dodge_" + side})

    def flip(self, beat):
        """Energy gate across the road: wrap under the track. Needs flat road at 0."""
        self.events.append({"beat": beat, "type": "flip"})
