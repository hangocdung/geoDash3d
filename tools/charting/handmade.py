"""Hand-charted terrain levels: each song lists `beat:pattern` steps chosen phrase by phrase on its drum hits.

This module parses the step list, checks it (the player has landed before each tap, ground height limits,
flat road for dodges and flips), places the patterns (terrain_patterns.py) and writes the chart.
Patterns: spike gap step step1 chain2 chain3 orb trip stairs fstairs pad dl dr flip drop drop2 drop4
(drop/drop2/drop4: run off the ledge down to 0 / 2 / 4).
Usage: a song script calls build(SONG, STEPS) (see tools/charting/levels/*.py).
Related: tools/charting/terrain_patterns.py, docs/chart_format.md
"""
import json
import math
import sys

from terrain_patterns import Level, SpeedMap, fall_beats, PLAYER_HALF_LENGTH

MAX_HEIGHT = 6.0
EPSILON = 0.0001


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
        self.level = level
        self.free = -100.0
        self.errors = []

    def need(self, condition, beat, message):
        if not condition:
            self.errors.append("beat %.2f: %s" % (beat, message))

    def apply(self, beat, name):
        level = self.level
        ground = level.ground
        speed = level.speed.speed_at(beat)
        if name.startswith("drop"):
            target = {"drop": 0.0, "drop2": 2.0, "drop4": 4.0}[name]
            self.need(ground > target, beat, "drop from %.1f to %.1f" % (ground, target))
            self.need(beat >= self.free - EPSILON, beat, "drop before landing (free at %.2f)" % self.free)
            level.drop(beat, target)
            self.free = beat + fall_beats(ground - target) + PLAYER_HALF_LENGTH / speed + 0.05
            return
        start = level.pad_trigger(beat) - 0.05 if name == "pad" else beat
        self.need(start >= self.free - EPSILON, beat, "%s before the player is free (%.2f)" % (name, self.free))
        rise = {"step": 1.5, "step1": 1.0, "orb": 2.0, "trip": 4.0, "stairs": 4.5, "fstairs": 4.5, "pad": 4.0}.get(name, 0.0)
        self.need(ground + rise <= MAX_HEIGHT, beat, "%s from height %.1f goes above %.1f" % (name, ground, MAX_HEIGHT))
        if name in ("dl", "dr", "flip"):
            self.need(ground == 0.0, beat, "%s needs the road (height 0), ground is %.1f" % (name, ground))
        if name == "spike":
            level.spike(beat)
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
        else:
            self.errors.append("beat %.2f: unknown pattern '%s'" % (beat, name))


def build(song, steps):
    """`song`: id, title, artist, bpm, offset, end_beat, speed, sections, cameras, track, vfx; optional audio
    (mp3 base name when several charts share one song, default id)."""
    level = Level(SpeedMap(song["speed"]))
    checker = Checker(level)
    previous = -100.0
    for beat, name in parse(steps):
        checker.need(beat > previous, beat, "steps out of order")
        previous = beat
        checker.apply(beat, name)
    if checker.errors:
        print("\n".join(checker.errors))
        sys.exit(1)
    events = list(level.events)
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
        "speed": [{"beat": b, "units_per_beat": rate} for b, rate in song["speed"]],
        "sections": [{"beat": b, "name": name, "energy": energy} for b, name, energy in song["sections"]],
        "track": [dict(beat=b, **shape) for b, shape in song["track"]],
        "terrain": level.terrain,
        "events": events,
    }
    path = "assets/music/%s.chart.json" % song["id"]
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(chart, handle, indent="\t")
        handle.write("\n")
    taps = sum(1 for e in events if e["type"] in ("jump", "orb", "dodge_left", "dodge_right", "flip"))
    print("wrote %s: %d taps, end beat %d" % (path, taps, song["end_beat"]))
