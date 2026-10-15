"""Build a terrain level from a record-mode tap recording: the taps choose *when*, this tool chooses *what*.

Each tap marks a moment the player acts. Taps are quantized to the grid, then grouped: three taps 0.5 beat apart
-> orb triplet, 0.75 apart -> stairs, two taps 0.5 apart -> a rotation of orb / dive under a spiked ceiling / big
orb; any other tap is one obstacle picked from a rotation that depends on the section energy (spike, saw, spike
rows, hole, ledge, two-lane wall, gate), falling back to whatever fits. Ledges are left with a drop where there is room (always before walls and gates). Lanes in old recordings
are ignored.
Every choice goes through handmade.Checker (the rules of hand-written levels); a tap that fits nothing is
skipped with a warning. Tempo, speed, sections, track, cameras and vfx are copied from the source chart.
Usage: python tools/charting/recording_level.py [<id> or chart path] [--grid=0.5] [--out=<path>] (no id: list songs)
Writes assets/music/<id>.rec.chart.json (listed in the song menu). Related: handmade.py, src/authoring/recorder/
"""
import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from handmade import Checker, EPSILON, MAX_HEIGHT, try_apply  # noqa: E402
from terrain_patterns import Level, SpeedMap  # noqa: E402

MUSIC_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "music"))
GAMEPLAY_EVENTS = {"jump", "orb", "orb_big", "orb_drop", "pad", "dodge_left", "dodge_right", "flip", "roll"}
ROAD_PATTERNS = ("dl", "dr", "flip", "roll")
# No obstacle before this beat (the run-up) or in the last beat of the song.
FIRST_BEAT = 2.0
# Leave a ledge when the next tap is at least this long after landing; stay up for quicker rhythms.
DROP_REST_BEATS = 2.0
# Run this long on a ledge before dropping, so the ledge reads as a platform.
LEDGE_RUN_BEATS = 0.5
HIGH_ENERGY = 0.8
# Rotation of obstacles for single taps ("wall" alternates dodge left/right); calm sections stay simpler.
AUTO_CALM = ["spike", "saw", "step", "laser", "spike2", "gap", "wall", "mine", "spike", "step1"]
AUTO_HIGH = ["spike2", "gap", "wall", "step", "pendulum", "saw", "flip", "spike3", "gap", "laser", "wall", "roll",
             "spike"]
SINGLE_FALLBACKS = ["spike", "gap", "step", "step1", "saw", "wall", "flip"]
# Two taps half a beat apart: plain orb, dive under a spiked ceiling, big orb (each needs more room after it).
PAIRS = ["orb", "dive", "orb", "borb"]


def same_gap(gap, target):
    """Tap spacing equal to `target` beats (tolerant to float error: hit_level.py taps are not on a grid)."""
    return abs(gap - target) < 1e-6


class Tempo:
    def __init__(self, chart):
        self.offset = float(chart.get("offset_sec", 0.0))
        self.keys = [(float(k["beat"]), float(k["bpm"])) for k in chart["tempo"]]

    def beat_at(self, time_sec):
        elapsed = time_sec - self.offset
        for index, (beat, bpm) in enumerate(self.keys):
            span_end = self.keys[index + 1][0] if index + 1 < len(self.keys) else math.inf
            span_sec = (span_end - beat) * 60.0 / bpm
            if elapsed < span_sec or span_end == math.inf:
                return beat + elapsed * bpm / 60.0
            elapsed -= span_sec
        return 0.0


def load_taps(recording, tempo, grid, end_beat, warnings):
    taps = set()
    for tap in recording.get("taps", []):
        beat = round(tempo.beat_at(float(tap["time_sec"])) / grid) * grid
        if beat < FIRST_BEAT or beat > end_beat - 1.0:
            warnings.append("beat %.2f: outside the playable range (%.0f..%.0f), skipped" % (beat, FIRST_BEAT, end_beat - 1))
        elif beat in taps:
            warnings.append("beat %.2f: two taps on the same grid step, kept one" % beat)
        else:
            taps.add(beat)
    return sorted(taps)


class Builder:
    def __init__(self, chart, taps, warnings):
        self.checker = Checker(Level(SpeedMap([(float(k["beat"]), float(k["units_per_beat"])) for k in chart["speed"]])))
        self.sections = [(float(s["beat"]), float(s.get("energy", 0.5))) for s in chart.get("sections", [])]
        self.end_beat = float(chart["end_beat"])
        self.taps = taps
        self.warnings = warnings
        self.steps = []
        self.auto_count = 0
        self.pair_count = 0
        self.wall_left = True

    def energy_at(self, beat):
        energy = 0.5
        for start, value in self.sections:
            if beat >= start:
                energy = value
        return energy

    def try_apply(self, beat, name, deadline):
        """Applies a pattern if the checker accepts it and the player is free again by `deadline`."""
        if not try_apply(self.checker, beat, name, deadline):
            return False
        self.steps.append((beat, name))
        return True

    def candidates(self, index):
        beat = self.taps[index]
        gaps = [self.taps[index + k] - self.taps[index + k - 1] if index + k < len(self.taps) else math.inf
                for k in (1, 2)]
        result = []
        if same_gap(gaps[0], 0.5) and same_gap(gaps[1], 0.5):
            result.append(("trip", 3))
        if same_gap(gaps[0], 0.75) and same_gap(gaps[1], 0.75):
            result.append(("fstairs" if self.energy_at(beat) >= HIGH_ENERGY else "stairs", 3))
        if same_gap(gaps[0], 0.5):
            preferred_pair = PAIRS[self.pair_count % len(PAIRS)]
            result += [(name, 2) for name in [preferred_pair] + [n for n in ("orb", "dive", "borb") if n != preferred_pair]]
        rotation = AUTO_HIGH if self.energy_at(beat) >= HIGH_ENERGY else AUTO_CALM
        preferred = rotation[self.auto_count % len(rotation)]
        wall = "dl" if self.wall_left else "dr"
        singles = [preferred] + [n for n in SINGLE_FALLBACKS if n != preferred]
        result += [(wall if name == "wall" else name, 1) for name in singles]
        return result

    def drop_before(self, beat, need_road, force=False):
        """Leaves the current ledge before `beat` when needed or when there is a rest."""
        level, checker = self.checker.level, self.checker
        if level.ground <= 0.0:
            return
        if not (force or need_road or beat - checker.free >= DROP_REST_BEATS or level.ground > MAX_HEIGHT - 2.0):
            return
        earliest = math.ceil((checker.free + LEDGE_RUN_BEATS) * 4.0) / 4.0
        for start in (earliest, math.ceil(checker.free * 4.0) / 4.0):
            for name, height in (("drop", 0.0), ("drop2", 2.0), ("drop4", 4.0)):
                if height < level.ground and self.try_apply(start, name, beat):
                    return

    def place(self, index, options, skip_blocker=False):
        beat = self.taps[index]
        if not skip_blocker:
            for name, count in options:
                if self.try_apply(beat, name, self.deadline(index + count)):
                    return name, count
            return None
        # A stray tap right after this one (double tap, early finger) blocks every pattern: drop that one instead.
        for name, count in options:
            blocker = index + count
            if blocker < len(self.taps) and self.try_apply(beat, name, self.deadline(blocker + 1)):
                self.warnings.append("beat %.2f: tap skipped, too close after the %s at %.2f"
                                     % (self.taps[blocker], name, beat))
                del self.taps[blocker]
                return name, count
        return None

    def deadline(self, index):
        return self.taps[index] if index < len(self.taps) else self.end_beat

    def build(self):
        index = 0
        while index < len(self.taps):
            beat = self.taps[index]
            options = self.candidates(index)
            self.drop_before(beat, options[0][0] in ROAD_PATTERNS)
            chosen = self.place(index, options)
            if chosen is None and self.checker.level.ground > 0.0:
                # Too high for every pattern: leave the ledge first, then try again.
                self.drop_before(beat, False, force=True)
                chosen = self.place(index, options)
            if chosen is None:
                chosen = self.place(index, options, skip_blocker=True)
            if chosen is None:
                busy = self.checker.free > beat + EPSILON
                self.warnings.append("beat %.2f: tap skipped, %s" % (beat, (
                    "too close to the previous obstacle (player busy until %.2f)" % self.checker.free) if busy
                    else "no pattern fits before the next tap"))
                index += 1
                continue
            name, count = chosen
            if name in ("dl", "dr"):
                self.wall_left = not self.wall_left
            if count == 1:
                self.auto_count += 1
            elif count == 2:
                self.pair_count += 1
            index += count
        self.drop_before(self.end_beat, False, force=True)


def list_songs():
    print("songs (id -> recording):")
    for name in sorted(os.listdir(MUSIC_DIR)):
        if not name.endswith(".chart.json") or name.endswith((".rec.chart.json", ".classic.chart.json")):
            continue
        song_id = name[:-len(".chart.json")]
        recording = os.path.join(MUSIC_DIR, song_id + ".recording.json")
        if os.path.exists(recording):
            with open(recording, encoding="utf-8") as handle:
                status = "%d taps" % len(json.load(handle).get("taps", []))
        else:
            status = "no recording yet"
        print("  %-40s %s" % (song_id, status))
    print("usage: python tools/charting/recording_level.py <id>")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("chart", nargs="?",
                        help="song id (e.g. pulse_drive) or chart path; no argument lists the songs and their recordings")
    parser.add_argument("--recording", help="default: <id>.recording.json next to the chart")
    parser.add_argument("--grid", type=float,
                        help="quantization step in beats (default: the grid saved by the recorder, else 0.25)")
    parser.add_argument("--out", help="default: <id>.rec.chart.json next to the chart")
    args = parser.parse_args()
    if args.chart is None:
        list_songs()
        return
    chart_path = args.chart if args.chart.endswith(".chart.json") else os.path.join(MUSIC_DIR, args.chart + ".chart.json")
    if not os.path.isfile(chart_path):
        print("chart not found: %s" % chart_path)
        list_songs()
        sys.exit(1)
    base = chart_path[:-len(".chart.json")]
    base = base[:-len(".rec")] if base.endswith(".rec") else base
    recording_path = args.recording or base + ".recording.json"
    out_path = args.out or base + ".rec.chart.json"
    with open(chart_path, encoding="utf-8") as handle:
        chart = json.load(handle)
    if not os.path.exists(recording_path):
        sys.exit("no recording at %s: open RECORD (DEV), pick this song, tap along and press S (or Esc) to save"
                 % recording_path)
    warnings = []
    with open(recording_path, encoding="utf-8") as handle:
        recording = json.load(handle)
    grid = args.grid or float(recording.get("grid", 0.25))
    taps = load_taps(recording, Tempo(chart), grid, float(chart["end_beat"]), warnings)
    recorded = len(taps)
    builder = Builder(chart, taps, warnings)
    builder.build()
    level = builder.checker.level
    events = [e for e in chart.get("events", []) if e["type"] not in GAMEPLAY_EVENTS] + list(level.events)
    events.sort(key=lambda event: (event["beat"], event["type"]))
    chart["title"] = chart["title"].removesuffix(" (Rec)") + " (Rec)"
    chart["terrain"] = level.terrain
    chart["events"] = events
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(chart, handle, indent="\t")
        handle.write("\n")
    for warning in sorted(warnings, key=lambda text: float(text.split(":")[0].split()[1])):
        print("WARN " + warning)
    used = sum(1 for e in level.events if e["type"] in GAMEPLAY_EVENTS - {"pad"})
    patterns = {}
    for _, name in builder.steps:
        patterns[name] = patterns.get(name, 0) + 1
    print("wrote %s: %d of %d recorded taps placed, %d warnings" % (out_path, used, recorded, len(warnings)))
    print("patterns: " + ", ".join("%s %d" % item for item in sorted(patterns.items())))


if __name__ == "__main__":
    main()
