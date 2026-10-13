"""Draft a playable chart from an analysis JSON (tools/audio/analyze_song.py) + a level plan.

Usage: python tools/audio/draft_chart.py <analysis.json> <plan.json> <out.chart.json>

The plan holds the hand-authored parts (sections, density rules, track shape, camera, vfx).
This script only picks *where* actions go: strong onsets snapped to a half-beat grid, the strongest
first, respecting per-section minimum gaps; kick-heavy hits become jumps, snare-heavy hits dashes.
Re-run after editing the plan; hand edits to the output should go into the plan instead.

Optional plan keys:
  "fixed":     [{"beat": 104, "type": "jump"}, ...]   hand-placed actions, always kept
  "recording": {"file": "<id>.recording.json", "lane_actions": ["jump", "dash"], "grid": 0.5,
                "mode": "replace" | "merge"}           taps from record mode / .sm import
"""
import json
import os
import sys

GRID = 0.5
SNAP_TOLERANCE_BEATS = 0.14
# Beats after an action before the next cue (action duration + ~0.5 beat of breathing room).
ACTION_RECOVERY_BEATS = {"jump": 1.5, "dodge_left": 1.75, "dodge_right": 1.75, "flip": 2.5}


# Relative difficulty of one action (used for the per-section report and the ramp test).
DIFFICULTY_WEIGHTS = {"jump": 1.0, "dodge_left": 1.25, "dodge_right": 1.25, "flip": 1.75}
BASE_SPEED = 7.0


def speed_at(plan, beat):
    speed = plan["speed"][0]["units_per_beat"]
    for point in plan["speed"]:
        if point["beat"] <= beat:
            speed = point["units_per_beat"]
    return speed


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def section_for(beat, sections):
    current = sections[0]
    for section in sections:
        if section["beat"] <= beat:
            current = section
    return current


def collect_candidates(analysis, plan):
    offset = analysis["offset_sec"]
    seconds_per_beat = 60.0 / analysis["bpm"]
    weights = plan["band_weights"]
    grid = {}
    for band, onsets in analysis["onsets"].items():
        for time_sec, strength in onsets:
            beat = (time_sec - offset) / seconds_per_beat
            snapped = round(beat / GRID) * GRID
            if abs(beat - snapped) > SNAP_TOLERANCE_BEATS:
                continue
            slot = grid.setdefault(snapped, {"low": 0.0, "mid": 0.0, "high": 0.0})
            slot[band] = max(slot[band], strength)
    candidates = []
    for beat, bands in grid.items():
        score = sum(bands[name] * weights[name] for name in bands)
        if beat == int(beat):
            score += plan["on_beat_bonus"]
        if beat % 4 == 0:
            score += plan["downbeat_bonus"]
        candidates.append({"beat": beat, "score": score, "bands": bands})
    return candidates


def dodge_side(beat, previous_types):
    """Deterministic left/right pattern with occasional repeats; never three dodges to the same side."""
    side = "dodge_left" if (int(beat * 2) // 3) % 2 == 0 else "dodge_right"
    recent = [t for t in previous_types if t.startswith("dodge")][-2:]
    if len(recent) == 2 and recent[0] == recent[1] == side:
        side = "dodge_right" if side == "dodge_left" else "dodge_left"
    return side


def choose_type(candidate, rules, previous_types):
    """Kick-heavy hits jump; snare/mid-heavy hits dodge (when the section allows dodges)."""
    bands = candidate["bands"]
    allowed = rules.get("actions", ["jump"])
    wants_dodge = "dodge" in allowed and bands["mid"] > bands["low"] * rules.get("dodge_bias", 1.0)
    action = dodge_side(candidate["beat"], previous_types) if wants_dodge else "jump"
    family = [t.split("_")[0] for t in previous_types[-3:]]
    if len(family) == 3 and all(f == action.split("_")[0] for f in family) and "dodge" in allowed:
        action = "jump" if action != "jump" else dodge_side(candidate["beat"], previous_types)
    return action


def gap_ok(beat, action, accepted):
    for other in accepted:
        first, second = (other, {"beat": beat, "type": action}) if other["beat"] < beat else ({"beat": beat, "type": action}, other)
        if second["beat"] - first["beat"] < ACTION_RECOVERY_BEATS[first["type"]]:
            return False
    return True


def load_recorded_actions(plan, plan_dir, analysis):
    settings = plan.get("recording")
    if not settings:
        return []
    path = os.path.join(plan_dir, settings["file"])
    if not os.path.exists(path):
        print("WARN recording %s not found, ignoring" % path)
        return []
    offset = analysis["offset_sec"]
    seconds_per_beat = 60.0 / analysis["bpm"]
    grid = settings.get("grid", GRID)
    lane_actions = settings["lane_actions"]
    events = {}
    for tap in load(path)["taps"]:
        lane = tap.get("lane", 0)
        if lane >= len(lane_actions):
            continue
        beat = round((tap["time_sec"] - offset) / seconds_per_beat / grid) * grid
        events.setdefault(beat, {"beat": beat, "type": lane_actions[lane]})
    return [events[b] for b in sorted(events)]


def accept_fixed(fixed_events):
    """Keeps fixed events in time order, dropping any that would be unreachable after the previous one."""
    accepted = []
    for event in sorted(fixed_events, key=lambda e: e["beat"]):
        if event["type"] not in ACTION_RECOVERY_BEATS:
            print("WARN unknown action type %s at beat %s, dropped" % (event["type"], event["beat"]))
        elif gap_ok(event["beat"], event["type"], accepted):
            accepted.append(dict(event))
        else:
            print("WARN action at beat %s too close to the previous one, dropped" % event["beat"])
    return accepted


def pick_actions(candidates, plan, fixed_events, auto_fill):
    sections = plan["sections"]
    accepted = accept_fixed(fixed_events)
    if not auto_fill:
        return accepted
    for candidate in sorted(candidates, key=lambda c: -c["score"]):
        beat = candidate["beat"]
        if beat < plan["first_action_beat"] or beat > plan["last_action_beat"]:
            continue
        rules = plan["rules"][section_for(beat, sections)["name"]]
        if candidate["score"] < rules["threshold"]:
            continue
        previous = [a["type"] for a in sorted(accepted, key=lambda a: a["beat"]) if a["beat"] < beat]
        action = choose_type(candidate, rules, previous)
        min_gap = rules["min_gap"]
        if any(abs(a["beat"] - beat) < min_gap for a in accepted):
            continue
        if not gap_ok(beat, action, accepted):
            continue
        accepted.append({"beat": beat, "type": action})
    accepted.sort(key=lambda a: a["beat"])
    return accepted


def main():
    analysis_path, plan_path, out_path = sys.argv[1:4]
    analysis, plan = load(analysis_path), load(plan_path)
    recorded = load_recorded_actions(plan, os.path.dirname(os.path.abspath(plan_path)), analysis)
    auto_fill = plan.get("recording", {}).get("mode", "merge") != "replace"
    actions = pick_actions(collect_candidates(analysis, plan), plan, plan.get("fixed", []) + recorded, auto_fill)
    events = actions + plan.get("camera", []) + plan.get("vfx", [])
    events.sort(key=lambda e: (e["beat"], e["type"]))
    chart = {
        "version": 1,
        "title": plan["title"],
        "artist": plan.get("artist", ""),
        "song": plan["song"],
        "offset_sec": analysis["offset_sec"],
        "end_beat": plan["end_beat"],
        "tempo": [{"beat": 0, "bpm": analysis["bpm"]}],
        "speed": plan["speed"],
        "sections": [{k: s[k] for k in ("beat", "name", "energy")} for s in plan["sections"]],
        "track": plan["track"],
        "events": events,
    }
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(chart, handle, indent="\t")
        handle.write("\n")
    by_type = {}
    for action in actions:
        by_type[action["type"]] = by_type.get(action["type"], 0) + 1
    print("DRAFT %d actions %s -> %s" % (len(actions), by_type, out_path))
    sections = plan["sections"]
    for index, section in enumerate(sections):
        end = sections[index + 1]["beat"] if index + 1 < len(sections) else plan["end_beat"]
        inside = [a for a in actions if section["beat"] <= a["beat"] < end]
        span = max(end - max(section["beat"], 0), 1)
        difficulty = sum(DIFFICULTY_WEIGHTS[a["type"]] * speed_at(plan, a["beat"]) / BASE_SPEED for a in inside)
        print("  %-10s beats %4g-%-4g %3d actions  %.2f per 16 beats  difficulty %.2f" % (
            section["name"], section["beat"], end, len(inside), len(inside) * 16.0 / span, difficulty * 16.0 / span))


main()
