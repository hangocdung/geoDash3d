"""Flap cues for a flight section (gameplay v4), placed on the music's standout hits.

Chooses flap beats on a sixteenth-note grid with the game's flight physics (GameplayConfig: fly_entry lift, flap =
1 high over 1 beat: flaps 0.5 apart climb 1, 1 apart hold, 1.5 apart sink 3). A dynamic programme over
(flap beat, height) picks the sequence that keeps the glider between LOW and HIGH while flapping on hits that clearly
stand out (standout ratio as in tap_salience.py); weak hits cost more the weaker they are. The loader then builds
the spike corridor around this path.
Usage: from handmade.build (pattern `<beat>:fly<length>`).   Related: tools/charting/handmade.py, tap_salience.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loudness_onsets import decode  # noqa: E402
from tap_salience import NEIGHBOUR_SLOTS, envelope, onset_strength, strength_at  # noqa: E402

# Must match GameplayConfig (_flap, fly_entry): launch speed 4h/d and gravity 8h/d^2, in units and beats.
FLAP_VELOCITY = 4.0 * 1.0 / 1.0
FLAP_GRAVITY = 8.0 * 1.0 / (1.0 * 1.0)
ENTRY_VELOCITY = 4.0 * 3.0 / 1.5
ENTRY_GRAVITY = 8.0 * 3.0 / (1.5 * 1.5)
LOW, HIGH = 1.8, 5.6
GRID = 0.25
GAPS = (0.5, 0.75, 1.0, 1.25, 1.5)
STANDOUT = 1.6
WEAK_COST = 10.0
HEIGHT_STEP = 0.05
# The loader requires the path to stay above GameplayConfig.fly_min_height (0.6); keep a margin.
MIN_PATH = 0.9


def standout_curve(audio_path, bpm, offset_sec):
    """beat -> how much the hit at that beat stands out from the quarter-beat slots around it."""
    strength = onset_strength(envelope(decode(audio_path)))
    seconds_per_beat = 60.0 / bpm

    def standout(beat):
        time_sec = offset_sec + beat * seconds_per_beat
        around = [strength_at(strength, time_sec + slot * seconds_per_beat) for slot in NEIGHBOUR_SLOTS]
        return strength_at(strength, time_sec) / max(sum(around) / len(around), 1e-9)
    return standout


def _height(arc, beat):
    start, height, velocity, gravity = arc
    t = beat - start
    return height + velocity * t - 0.5 * gravity * t * t


def plan_flaps(start, end, standout):
    """Flap beats for a flight section [start, end); raises ValueError when no sequence keeps the height."""
    rise = {gap: FLAP_VELOCITY * gap - 0.5 * FLAP_GRAVITY * gap * gap for gap in GAPS}
    apex = FLAP_VELOCITY * FLAP_VELOCITY / (2.0 * FLAP_GRAVITY)

    def cost(beat):
        return max(STANDOUT - standout(beat), 0.0) * WEAK_COST

    # best[(beat, height bucket)] = (total cost, previous key); the lift-off allows a first flap up to a beat in.
    best = {}
    for first in (0.5, 0.75, 1.0):
        height = _height((start, 0.0, ENTRY_VELOCITY, ENTRY_GRAVITY), start + first)
        if height >= LOW:
            best[(start + first, round(height / HEIGHT_STEP))] = (cost(start + first), None)
    frontier = sorted(best)
    finished = []
    while frontier:
        key = frontier.pop(0)
        beat, bucket = key
        height = bucket * HEIGHT_STEP
        if end - beat <= max(GAPS):
            # The glider falls freely from here to the end: it must not sink under LOW before it.
            if height + rise.get(round((end - beat) * 4.0) / 4.0, -100.0) >= LOW or end - beat <= 1.0:
                finished.append(key)
        for gap in GAPS:
            following = beat + gap
            landing = height + rise[gap]
            if following >= end - GRID + 1e-9 or landing < LOW or height + apex > HIGH:
                continue
            next_key = (following, round(landing / HEIGHT_STEP))
            total = best[key][0] + cost(following)
            if next_key not in best or total < best[next_key][0]:
                if next_key not in best:
                    frontier.append(next_key)
                    frontier.sort()
                best[next_key] = (total, key)
    if not finished:
        raise ValueError("flight %.2f..%.2f: no flap sequence keeps the glider between %.1f and %.1f"
                         % (start, end, LOW, HIGH))
    key = min(finished, key=lambda item: best[item][0])
    flaps = []
    while key is not None:
        flaps.append(key[0])
        key = best[key][1]
    flaps.reverse()
    _check(start, end, flaps)
    return flaps


def _check(start, end, flaps):
    arc = (start, 0.0, ENTRY_VELOCITY, ENTRY_GRAVITY)
    index = 0
    beat = start + 1.0
    while beat < end:
        while index < len(flaps) and flaps[index] <= beat:
            arc = (flaps[index], _height(arc, flaps[index]), FLAP_VELOCITY, FLAP_GRAVITY)
            index += 1
        if _height(arc, beat) < MIN_PATH:
            raise ValueError("flight %.2f..%.2f: the path dips to %.2f at beat %.2f" % (start, end, _height(arc, beat),
                                                                                     beat))
        beat += 1.0 / 48.0
