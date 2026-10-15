"""Hand-charted terrain levels: each song lists `beat:pattern` steps chosen phrase by phrase on its drum hits.

This module parses the step list, checks it (the player has landed before each tap, ground height limits,
flat road for dodges and flips), places the patterns (terrain_patterns.py) and writes the chart.
Patterns: spike spike2 spike3 saw laser pendulum mine roll gap step step1 chain2 chain3 orb borb dive trip stairs fstairs pad dl dr flip
drop drop2 drop4 fdown fup (drop/drop2/drop4: run off the ledge down to 0 / 2 / 4; spike2/spike3: spike rows; borb:
big orb onto +2, lands 2 beats after the jump; dive: jump + dive orb under a spiked ceiling; fdown ... fup: underside
run, only spike patterns and chains in between, the hazards hang under the track; flyN: an N-beat flight section
from the road, flaps on the standout hits (flight_patterns.py); amine: a floating mine inside a flight).
build() adds variety by default: plain `spike` steps rotate through spike / saw / spike rows by section energy, and
every other `orb` with room after it becomes `borb` (same taps, same ground).
Usage: a song script calls build(SONG, STEPS) (see tools/charting/levels/*.py).
Related: tools/charting/terrain_patterns.py, docs/chart_format.md
"""
import json
import math
import sys

import flight_patterns
from terrain_patterns import Level, SpeedMap, fall_beats, PLAYER_HALF_LENGTH

MAX_HEIGHT = 6.0
# GameplayConfig.fly_exit_beats: the first ground tap after a flight comes this long after it (time to land).
FLY_EXIT_BEATS = 2.0
EPSILON = 0.0001
SPIKE_HAZARDS = {"spike": "spike", "spike2": "spike_double", "spike3": "spike_triple", "saw": "saw",
                 "laser": "laser_fence", "pendulum": "pendulum", "mine": "spike_mine"}
# Variety rotations for plain spikes, by section energy (below 0.5 / below 0.8 / above). GD3-104 adds the laser
# fence, the swinging axe and the spiked mine (same jump, same or looser hitbox).
SPIKE_VARIETY = (["spike", "laser", "saw", "mine"],
                 ["spike", "saw", "pendulum", "spike2", "laser", "mine"],
                 ["spike", "spike2", "pendulum", "saw", "spike3", "laser", "mine"])
BIG_ORB_LANDING = 2.0
# GD3-112: what can be played under the track (plain jumps over hazards hanging there).
UNDER_PATTERNS = set(SPIKE_HAZARDS) | {"chain2", "chain3"}
# The fup's gate hangs under the road 1.25 beats after the tap: no hole in the road until it has passed.
UNDER_GATE_CLEAR = 1.75


def landing_after_step(rise):
    """Beats from take-off to landing on a ledge `rise` higher (jump: 1 beat, peak 2)."""
    return (1.0 + math.sqrt(max(1.0 - rise / 2.0, 0.0))) / 2.0


def parse(steps):
    plan = []
    for line in steps.splitlines():
        line = line.split(";", 1)[0]
        for token in line.split():
            beat, name = token.split(":")
            plan.append((float(beat), name))
    return plan


class Checker:
    def __init__(self, level):
        self.fly = []
        self.mines = []
        self.level = level
        self.free = -100.0
        self.errors = []
        # Between an fdown and its fup: the player runs under the track.
        self.under = False
        self.solid_until = -100.0

    def need(self, condition, beat, message):
        if not condition:
            self.errors.append("beat %.2f: %s" % (beat, message))

    def snapshot(self):
        level = self.level
        return (len(level.events), len(level.terrain), level.ground, self.free, len(self.errors), self.under,
                self.solid_until)

    def restore(self, saved):
        level = self.level
        del level.events[saved[0]:]
        del level.terrain[saved[1]:]
        level.ground, self.free = saved[2], saved[3]
        del self.errors[saved[4]:]
        self.under, self.solid_until = saved[5], saved[6]

    def apply(self, beat, name):
        first = len(self.level.terrain)
        self._apply(beat, name)
        for piece in self.level.terrain[first:]:
            if piece.get("gap") and piece["beat"] < self.solid_until:
                self.errors.append("beat %.2f: %s opens a hole under the last fup's gate (road solid until %.2f)"
                                   % (beat, name, self.solid_until))

    def _apply(self, beat, name):
        level = self.level
        if name == "amine":
            self.need(any(start + 1.0 < beat < end - 0.5 for start, end in self.fly), beat, "amine outside a flight")
            self.mines.append(beat)
            return
        ground = level.ground
        speed = level.speed.speed_at(beat)
        if self.under and name not in UNDER_PATTERNS and name != "fup":
            self.errors.append("beat %.2f: %s under the track (only spike patterns until fup)" % (beat, name))
            return
        if name.startswith("drop"):
            target = {"drop": 0.0, "drop2": 2.0, "drop4": 4.0}[name]
            self.need(ground > target, beat, "drop from %.1f to %.1f" % (ground, target))
            self.need(beat >= self.free - EPSILON, beat, "drop before landing (free at %.2f)" % self.free)
            level.drop(beat, target)
            self.free = beat + fall_beats(ground - target) + PLAYER_HALF_LENGTH / speed + 0.05
            return
        start = level.pad_trigger(beat) - 0.05 if name == "pad" else beat
        self.need(start >= self.free - EPSILON, beat, "%s before the player is free (%.2f)" % (name, self.free))
        rise = {"step": 1.5, "step1": 1.0, "orb": 2.0, "borb": 2.0, "trip": 4.0, "stairs": 4.5, "fstairs": 4.5, "pad": 4.0}.get(name, 0.0)
        self.need(ground + rise <= MAX_HEIGHT, beat, "%s from height %.1f goes above %.1f" % (name, ground, MAX_HEIGHT))
        if name in ("dl", "dr", "flip", "roll", "fdown"):
            self.need(ground == 0.0, beat, "%s needs the road (height 0), ground is %.1f" % (name, ground))
        if name.startswith("fly"):
            self.need(ground == 0.0, beat, "fly needs the road (height 0), ground is %.1f" % ground)
            self.fly.append((beat, beat + float(name[3:])))
            self.free = beat + float(name[3:]) + FLY_EXIT_BEATS
        elif name in SPIKE_HAZARDS:
            level.spike(beat, SPIKE_HAZARDS[name])
            self.free = beat + 1.0
        elif name == "gap":
            level.gap(beat)
            self.free = beat + 1.0
        elif name in ("step", "step1"):
            level.step(beat, rise)
            self.free = beat + landing_after_step(rise)
        elif name in ("chain2", "chain3"):
            count = int(name[-1])
            level.chain(beat, count)
            self.free = beat + count
        elif name == "orb":
            level.orb_up(beat)
            self.free = beat + 1.5
        elif name == "borb":
            level.big_orb(beat)
            self.free = beat + BIG_ORB_LANDING
        elif name == "dive":
            self.free = level.dive(beat) + 0.05
        elif name == "trip":
            level.orb_triplet(beat)
            self.free = beat + 2.0
        elif name == "stairs":
            level.stairs(beat, 3)
            self.free = beat + 2.25
        elif name == "fstairs":
            level.floating_stairs(beat, 3)
            self.free = beat + 2.25
        elif name == "pad":
            level.pad(beat)
            self.free = level.pad_trigger(beat) + 1.0
        elif name in ("dl", "dr"):
            level.dodge(beat, "left" if name == "dl" else "right")
            self.free = beat + 1.25
        elif name == "flip":
            level.flip(beat)
            self.free = beat + 2.0
        elif name == "roll":
            level.roll(beat)
            self.free = beat + 2.0
        elif name == "fdown":
            self.need(not self.under, beat, "fdown while already under the track")
            level.flip_down(beat)
            self.under = True
            self.free = beat + 1.0
        elif name == "fup":
            self.need(self.under, beat, "fup without an fdown before it")
            level.flip_up(beat)
            self.under = False
            self.free = beat + 1.0
            self.solid_until = beat + UNDER_GATE_CLEAR
        else:
            self.errors.append("beat %.2f: unknown pattern '%s'" % (beat, name))


def try_apply(checker, beat, name, deadline):
    """Applies a pattern if the checker accepts it and the player is free again by `deadline`; else undoes it."""
    saved = checker.snapshot()
    checker.apply(beat, name)
    if len(checker.errors) == saved[4] and checker.free <= deadline + EPSILON:
        return True
    checker.restore(saved)
    return False


def add_variety(plan, sections):
    """Plain spikes rotate through saw / spike rows by section energy; every other orb with 2 beats of room
    after its jump becomes a big orb; every other flip becomes a roll (GD3-106). Same tap beats, same ground."""
    result = []
    spikes = 0
    orbs = 0
    flips = 0
    for index, (beat, name) in enumerate(plan):
        energy = 0.5
        for start, _, value in sections:
            if beat >= start:
                energy = value
        if name == "spike":
            rotation = SPIKE_VARIETY[0 if energy < 0.5 else 1 if energy < 0.8 else 2]
            name = rotation[spikes % len(rotation)]
            spikes += 1
        elif name == "flip":
            if flips % 2 == 1:
                name = "roll"
            flips += 1
        elif name == "orb":
            next_beat = plan[index + 1][0] if index + 1 < len(plan) else float("inf")
            if next_beat >= beat + BIG_ORB_LANDING:
                if orbs % 2 == 1:
                    name = "borb"
                orbs += 1
        result.append((beat, name))
    return result


def flight_events(song, checker):
    """Flap cues of every flight section (on the standout hits of the song) and its floating mines."""
    if not checker.fly:
        return []
    audio = "assets/music/%s.mp3" % song.get("audio", song["id"])
    standout = flight_patterns.standout_curve(audio, song["bpm"], song["offset"])
    events = []
    for start, end in checker.fly:
        try:
            events += [{"beat": beat, "type": "flap"} for beat in flight_patterns.plan_flaps(start, end, standout)]
        except ValueError as error:
            print(error)
            sys.exit(1)
    return events + [{"beat": beat, "type": "hazard", "hazard": "air_mine"} for beat in checker.mines]


def speed_keys(song):
    """Speed ladder: explicit `speed` keys, else one key per phase (beat, palette, units_per_beat)."""
    if "speed" in song:
        return song["speed"]
    return [(beat, rate) for beat, _, rate in song["phases"]]


def build(song, steps, variety=True):
    """`song`: id, title, artist, bpm, offset, end_beat, phases [(beat, palette, units_per_beat)] (or plain
    speed keys), sections, cameras, track, vfx; optional audio (mp3 base name when several charts share one
    song, default id). `variety`: see add_variety()."""
    level = Level(SpeedMap(speed_keys(song)))
    checker = Checker(level)
    previous = -100.0
    plan = parse(steps)
    if variety:
        plan = add_variety(plan, song["sections"])
    index = 0
    dive_chances = 0
    while index < len(plan):
        beat, name = plan[index]
        checker.need(beat > previous, beat, "steps out of order")
        previous = beat
        if variety and name == "orb" and index + 1 < len(plan) and plan[index + 1][1] == "drop" and level.ground == 0.0:
            # An orb up from the road that drops right back: every other one dives under a ceiling instead.
            dive_chances += 1
            following = plan[index + 2][0] if index + 2 < len(plan) else song["end_beat"]
            if dive_chances % 2 == 1 and try_apply(checker, beat, "dive", following):
                previous = plan[index + 1][0]
                index += 2
                continue
        checker.apply(beat, name)
        index += 1
    checker.need(not checker.under, song["end_beat"], "the last fdown has no fup")
    if checker.errors:
        print("\n".join(checker.errors))
        sys.exit(1)
    events = list(level.events) + flight_events(song, checker)
    events += [{"beat": b, "type": "camera", "shot": shot, "blend_beats": blend} for b, shot, blend in song["cameras"]]
    events += [{"beat": b, "type": "vfx", "name": name} for b, name in song.get("vfx", [])]
    events.sort(key=lambda event: (event["beat"], event["type"]))
    chart = {
        "version": 1,
        "title": song["title"],
        "artist": song["artist"],
        "song": "res://assets/music/%s.mp3" % song.get("audio", song["id"]),
        "offset_sec": song["offset"],
        "end_beat": song["end_beat"],
        "tempo": [{"beat": 0, "bpm": song["bpm"]}],
        "speed": [{"beat": b, "units_per_beat": rate} for b, rate in speed_keys(song)],
        "phases": [{"beat": b, "palette": palette} for b, palette, _ in song.get("phases", [])],
        "sections": [{"beat": b, "name": name, "energy": energy} for b, name, energy in song["sections"]],
        "track": [dict(beat=b, **shape) for b, shape in song["track"]],
        "terrain": level.terrain,
        "events": events,
    }
    if checker.fly:
        chart["fly"] = [{"beat": start, "end": end} for start, end in checker.fly]
    if "revision" in song:
        # Must beat the version of any downloaded package of this song (SongCatalog.merge_remote keeps the higher one).
        chart["chart_revision"] = song["revision"]
    path = "assets/music/%s.chart.json" % song["id"]
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(chart, handle, indent="\t")
        handle.write("\n")
    taps = sum(1 for e in events if e["type"] in ("jump", "orb", "orb_big", "orb_drop", "dodge_left", "dodge_right", "flip",
                                                  "roll", "flip_down", "flip_up", "flap"))
    print("wrote %s: %d taps, end beat %d" % (path, taps, song["end_beat"]))
