"""Generates a terrain level (gameplay v3) for any analysed song: sections from bar energy, patterns whose
taps land on the song's onsets, a difficulty ramp (unlocks, density, speed) and ground-height management.

Usage: python tools/charting/terrain_level.py <id.analysis.json> --title "Song" [--artist A] [--seed N]
       Writes assets/music/<id>.chart.json next to the analysis (or --out PATH).
Rules the game tests enforce (tests/gameplay/test_shipped_charts.gd): autoplay clears it, every cue is
playable on its beat (the next tap never comes before the landing), speed never drops, the last quarter is
much harder than the first. Check timing windows with tools/charting/tolerance_report.gd.
Related: tools/charting/terrain_patterns.py, tools/audio/analyze_song.py, docs/design/gameplay_v3.md
"""
import argparse
import json
import math
import os
import random

from terrain_patterns import Level, SpeedMap, fall_beats

GRID = 0.25
BAND_WEIGHTS = {"low": 1.0, "mid": 0.85, "high": 0.45}
MAX_HEIGHT = 6.0
START_BEAT = 8.0
# Beats of breathing room after a pattern, from the start of the level to its end (the difficulty ramp;
# the music's energy only changes which onsets and patterns are used).
REST_START = 4.0
REST_END = 0.0
SPEEDS = [7.0, 7.5, 8.0, 8.5]
# Camera shots: the first ones read terrain best; dodges need a shot that shows the lanes.
INTRO_SHOTS = ["side", "side_far"]
LANE_SHOTS = ["diagonal", "side_high", "diagonal", "high"]


class Pattern:
    def __init__(self, name, taps, busy, rise, unlock, weight, flat=False, anchor_only=False):
        self.name = name
        # Tap offsets in beats from the pattern start (all must sit on onsets).
        self.taps = taps
        # Beats from the start until the player is on the ground again (next tap allowed).
        self.busy = busy
        # Ground height change (None = ends on the same ground).
        self.rise = rise
        # Fraction of the level from which the pattern may appear.
        self.unlock = unlock
        self.weight = weight
        # Needs flat road at height 0 for its whole duration (dodge, flip).
        self.flat = flat
        # No tap: placed on a strong onset (pad).
        self.anchor_only = anchor_only


PATTERNS = [
    Pattern("spike", [0.0], 1.0, 0.0, 0.0, 1.0),
    Pattern("step", [0.0], 1.0, 1.5, 0.0, 0.9),
    Pattern("gap", [0.0], 1.0, 0.0, 0.0, 0.8),
    Pattern("chain2", [0.0, 1.0], 2.0, 0.0, 0.12, 1.0),
    Pattern("orb_up", [0.0, 0.5], 1.5, 2.0, 0.12, 1.0),
    Pattern("pad", [], 1.0, 4.0, 0.12, 0.5, anchor_only=True),
    Pattern("dodge", [0.0], 1.25, 0.0, 0.3, 0.9, flat=True),
    Pattern("stairs", [0.0, 0.75, 1.5], 2.25, 4.5, 0.3, 1.1),
    Pattern("chain3", [0.0, 1.0, 2.0], 3.0, 0.0, 0.3, 0.9),
    Pattern("flip", [0.0], 2.0, 0.0, 0.45, 0.7, flat=True),
    Pattern("orb_triplet", [0.0, 0.5, 1.0], 2.0, 4.0, 0.45, 0.9),
    Pattern("floating_stairs", [0.0, 0.75, 1.5], 2.25, 4.5, 0.55, 0.8),
]


def onset_grid(analysis):
    """Strongest weighted onset per 1/4 beat, keyed by grid beat."""
    seconds_per_beat = 60.0 / analysis["bpm"]
    grid = {}
    for band, onsets in analysis["onsets"].items():
        for time_sec, strength in onsets:
            beat = (time_sec - analysis["offset_sec"]) / seconds_per_beat
            snapped = round(beat / GRID) * GRID
            if abs(snapped - beat) < 0.09:
                grid[snapped] = max(grid.get(snapped, 0.0), strength * BAND_WEIGHTS.get(band, 0.5))
    return grid


def find_sections(analysis, end_beat):
    """Groups of 4 bars with similar energy, merged into sections; energy normalised to 0.2..1."""
    bars = analysis["bars"]
    loud = max(bar["rms"] for bar in bars) or 1.0
    blocks = []
    for start in range(0, len(bars), 4):
        group = bars[start:start + 4]
        if group[0]["beat"] >= end_beat:
            break
        level = sum(bar["rms"] for bar in group) / len(group) / loud
        blocks.append((group[0]["beat"], level))
    sections = []
    for beat, level in blocks:
        energy = round(0.2 + 0.8 * min(max((level - 0.35) / 0.6, 0.0), 1.0), 2)
        if sections and abs(sections[-1]["energy"] - energy) < 0.15:
            continue
        sections.append({"beat": beat, "energy": energy})
    sections[0]["beat"] = -16
    for index, section in enumerate(sections):
        if index == 0:
            section["name"] = "intro"
        elif section["energy"] >= 0.75:
            section["name"] = "drop"
        elif section["energy"] <= 0.4:
            section["name"] = "break"
        else:
            section["name"] = "verse"
    return sections


def section_at(sections, beat):
    current = sections[0]
    for section in sections:
        if section["beat"] <= beat:
            current = section
    return current


def level_end(analysis):
    """Bar after the last loud bar (the outro fades on the road)."""
    bars = analysis["bars"]
    loud = max(bar["rms"] for bar in bars)
    last = max(bar["beat"] for bar in bars if bar["rms"] > 0.45 * loud)
    return last + 4


class Generator:
    def __init__(self, analysis, seed):
        self.analysis = analysis
        self.grid = onset_grid(analysis)
        self.end_beat = level_end(analysis)
        self.sections = find_sections(analysis, self.end_beat)
        length = self.end_beat - START_BEAT
        self.speed_keys = [(0, SPEEDS[0])] + [(round((START_BEAT + length * q) / 4.0) * 4.0, SPEEDS[i + 1])
                                               for i, q in enumerate((0.25, 0.5, 0.75))]
        self.level = Level(SpeedMap(self.speed_keys))
        self.random = random.Random(seed)
        self.history = []
        self.counts = {}

    def strength(self, beat):
        return self.grid.get(round(beat / GRID) * GRID, 0.0)

    def progress(self, beat):
        return (beat - START_BEAT) / (self.end_beat - START_BEAT)

    def intensity(self, beat):
        """0..1 density driver: mostly how far into the level, partly how loud the music is (ramp first)."""
        return min(0.8 * self.progress(beat) + 0.2 * section_at(self.sections, beat)["energy"], 1.0)

    def fits(self, pattern, start, free_from):
        """Taps on onsets, ground allows it, the player is free. Returns the needed drop beat or None/-1."""
        level = self.level
        energy = section_at(self.sections, start)["energy"]
        follow_threshold = 0.32 - 0.12 * energy
        for offset in pattern.taps[1:]:
            if self.strength(start + offset) < follow_threshold:
                return None
        earliest = start - 0.3 if pattern.anchor_only else start
        needs_drop = level.ground > 0.0 and (pattern.flat or level.ground + (pattern.rise or 0.0) > MAX_HEIGHT)
        if not needs_drop:
            return -1.0 if earliest >= free_from else None
        drop_end = free_from + fall_beats(level.ground) + PLAYER_HALF_BEATS + 0.25
        return free_from if earliest >= drop_end else None

    def choose(self, start, free_from):
        progress = self.progress(start)
        energy = self.intensity(start)
        options = []
        for pattern in PATTERNS:
            if progress < pattern.unlock:
                continue
            drop = self.fits(pattern, start, free_from)
            if drop is None:
                continue
            weight = pattern.weight * (1.0 + energy * (len(pattern.taps) - 1) * 0.8)
            if self.history[-1:] == [pattern.name]:
                weight *= 0.25
            if self.history[-2:] == [pattern.name] * 2:
                weight = 0.0
            if pattern.flat and section_at(self.sections, start)["shot"] not in LANE_SHOTS:
                weight = 0.0
            if weight > 0.0:
                options.append((weight, pattern, drop))
        if not options:
            return None
        pick = self.random.uniform(0.0, sum(option[0] for option in options))
        for weight, pattern, drop in options:
            pick -= weight
            if pick <= 0.0:
                return pattern, drop
        return options[-1][1], options[-1][2]

    def place(self, pattern, start):
        level = self.level
        name = pattern.name
        if name == "spike":
            level.spike(start)
        elif name == "step":
            level.step(start, 1.5 if level.ground + 1.5 <= MAX_HEIGHT else 1.0)
        elif name == "gap":
            level.gap(start)
        elif name == "chain2":
            level.chain(start, 2)
        elif name == "chain3":
            level.chain(start, 3)
        elif name == "orb_up":
            level.orb_up(start)
        elif name == "orb_triplet":
            level.orb_triplet(start)
        elif name == "stairs":
            level.stairs(start, 3)
        elif name == "floating_stairs":
            level.floating_stairs(start, 3)
        elif name == "pad":
            level.pad(start)
        elif name == "dodge":
            level.dodge(start, "left" if self.counts.get("dodge", 0) % 3 != 1 else "right")
        elif name == "flip":
            level.flip(start)
        self.history.append(name)
        self.counts[name] = self.counts.get(name, 0) + 1

    def run(self):
        self.assign_cameras()
        free_from = START_BEAT
        beat = START_BEAT
        stop = self.end_beat - 4.0
        while beat < stop:
            # Pattern starts stay on the half-beat grid (the onsets), whatever the landings and drops did.
            beat = math.ceil(beat / 0.5 - 1e-6) * 0.5
            intensity = self.intensity(beat)
            threshold = 0.3 - 0.15 * intensity
            if self.strength(beat) < threshold or beat < free_from:
                beat += 0.5
                continue
            choice = self.choose(beat, free_from)
            if choice is None:
                beat += 0.5
                continue
            pattern, drop = choice
            if drop >= 0.0:
                self.level.drop(drop)
            self.place(pattern, beat)
            rest = REST_START + (REST_END - REST_START) * min(self.progress(beat), 1.0)
            free_from = beat + pattern.busy
            beat = free_from + rest
            # Come back down now and then, on the beat the player lands.
            height = self.level.ground
            if height >= 4.0 or (height > 0.0 and self.random.random() < 0.1):
                drop_at = max(free_from, beat - 1.0)
                landed = drop_at + fall_beats(height) + PLAYER_HALF_BEATS + 0.25
                if landed < stop:
                    self.level.drop(drop_at)
                    free_from = landed
                    beat = max(beat, free_from)
        return self.level

    def assign_cameras(self):
        lane_index = 0
        for section in self.sections:
            if section["beat"] < 0 or self.progress(section["beat"]) < 0.28:
                section["shot"] = INTRO_SHOTS[0]
            else:
                section["shot"] = LANE_SHOTS[lane_index % len(LANE_SHOTS)]
                lane_index += 1


# Margin for the player's half length at the slowest speed, in beats.
PLAYER_HALF_BEATS = 0.38 / SPEEDS[0]


def build_chart(analysis, title, artist, seed):
    generator = Generator(analysis, seed)
    level = generator.run()
    events = list(level.events)
    events.append({"beat": -8, "type": "camera", "shot": "front", "blend_beats": 0})
    previous_energy = 0.0
    track = [{"beat": 0, "shape": "straight"}]
    turn_sign = 1
    for index, section in enumerate(generator.sections):
        beat = max(section["beat"], -2)
        events.append({"beat": beat, "type": "camera", "shot": section["shot"], "blend_beats": 4 if index == 0 else 2})
        if index > 0 and section["energy"] - previous_energy >= 0.3:
            events.append({"beat": section["beat"], "type": "vfx", "name": "flash"})
            events.append({"beat": section["beat"], "type": "vfx", "name": "shockwave"})
        previous_energy = section["energy"]
        if index > 0 and index % 2 == 0 and section["beat"] + 8 < generator.end_beat:
            track.append({"beat": section["beat"], "shape": "turn", "angle_deg": 35 * turn_sign})
            track.append({"beat": section["beat"] + 8, "shape": "straight"})
            turn_sign = -turn_sign
    events.sort(key=lambda event: (event["beat"], event["type"]))
    song_id = os.path.basename(analysis["song"]).rsplit(".", 1)[0]
    return {
        "version": 1,
        "title": title,
        "artist": artist,
        "song": "res://assets/music/%s.mp3" % song_id,
        "offset_sec": round(analysis["offset_sec"], 4),
        "end_beat": generator.end_beat,
        "tempo": [{"beat": 0, "bpm": round(analysis["bpm"], 3)}],
        "speed": [{"beat": beat, "units_per_beat": rate} for beat, rate in generator.speed_keys],
        "sections": [{"beat": s["beat"], "name": s["name"], "energy": s["energy"]} for s in generator.sections],
        "track": track,
        "terrain": level.terrain,
        "events": events,
    }, generator


# Same weights as tests/gameplay/test_shipped_charts.gd (last quarter must exceed 1.5x the first).
DIFFICULTY_WEIGHTS = {"jump": 1.0, "orb": 1.0, "dodge_left": 1.25, "dodge_right": 1.25, "flip": 1.75}


def quarter_difficulty(chart, generator):
    quarter = chart["end_beat"] / 4.0
    first = last = 0.0
    for event in chart["events"]:
        weight = DIFFICULTY_WEIGHTS.get(event["type"])
        if weight is None:
            continue
        score = weight * generator.level.speed.speed_at(event["beat"])
        if event["beat"] < quarter:
            first += score
        elif event["beat"] >= chart["end_beat"] - quarter:
            last += score
    return first, last


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("analysis")
    parser.add_argument("--title", required=True)
    parser.add_argument("--artist", default="Unknown")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--out")
    args = parser.parse_args()
    with open(args.analysis, encoding="utf-8") as handle:
        analysis = json.load(handle)
    chart, generator = build_chart(analysis, args.title, args.artist, args.seed)
    out_path = args.out or args.analysis.replace(".analysis.json", ".chart.json")
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(chart, handle, indent="\t")
        handle.write("\n")
    taps = sum(1 for event in chart["events"] if event["type"] in DIFFICULTY_WEIGHTS)
    counts = ", ".join("%s %d" % item for item in sorted(generator.counts.items()))
    first, last = quarter_difficulty(chart, generator)
    print("wrote %s: %d beats, %d taps, %d sections, difficulty first/last quarter %.0f/%.0f (%s)" % (
        out_path, chart["end_beat"], taps, len(chart["sections"]), first, last, counts))


if __name__ == "__main__":
    main()
