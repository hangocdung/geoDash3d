"""Draft a playable chart from an analysis JSON (tools/audio/analyze_song.py) + a level plan.

Usage: python tools/audio/draft_chart.py <analysis.json> <plan.json> <out.chart.json>

The plan holds the hand-authored parts (sections, density rules, track shape, camera, vfx).
This script only picks *where* actions go: strong onsets snapped to a half-beat grid, the strongest
first, respecting per-section minimum gaps; kick-heavy hits become jumps, snare-heavy hits dashes.
Re-run after editing the plan; hand edits to the output should go into the plan instead.
"""
import json
import sys

GRID = 0.5
SNAP_TOLERANCE_BEATS = 0.14
ACTION_RECOVERY_BEATS = {"jump": 1.5, "dash": 1.25}


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


def choose_type(candidate, rules, previous_types):
    bands = candidate["bands"]
    allowed = rules.get("actions", ["jump"])
    wants_dash = "dash" in allowed and bands["mid"] > bands["low"] * rules.get("dash_bias", 1.0)
    action = "dash" if wants_dash else "jump"
    if len(previous_types) >= 3 and all(t == action for t in previous_types[-3:]) and len(allowed) > 1:
        action = "jump" if action == "dash" else "dash"
    return action


def gap_ok(beat, action, accepted):
    for other in accepted:
        first, second = (other, {"beat": beat, "type": action}) if other["beat"] < beat else ({"beat": beat, "type": action}, other)
        if second["beat"] - first["beat"] < ACTION_RECOVERY_BEATS[first["type"]]:
            return False
    return True


def pick_actions(candidates, plan):
    sections = plan["sections"]
    accepted = []
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
    actions = pick_actions(collect_candidates(analysis, plan), plan)
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


main()
