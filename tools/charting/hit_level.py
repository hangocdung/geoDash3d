"""Level from a song's standout hits: every tap lands on the exact time of one of the hits that stand out most
(tap_salience's two measures, taken at the hit itself, not on a grid), the obstacles come from
recording_level.Builder (the rules of hand-written levels) and sections, phases, track shapes and cameras are
derived from the loudness of each bar. A song script only gives tempo, title, palettes and a difficulty 1-5
(taps per bar, spacing, pairs and the speed ladder per phase).
Usage: a song script calls build(SONG) (see tools/charting/levels/temple_battle_taiko.py).
Related: tools/charting/tap_salience.py, tools/charting/recording_level.py, tools/charting/handmade.py
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from handmade import build as write_chart  # noqa: E402
from loudness_onsets import FRAME_SEC, decode, loudness_hits  # noqa: E402
from recording_level import Builder  # noqa: E402
from tap_salience import NEIGHBOUR_SLOTS, attack_at, envelope, onset_strength, strength_at  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FIRST_TAP_BEAT = 4.0
# Per difficulty: max taps per bar, min beats between taps, first phase allowing 0.5-beat pairs, speed ladder.
DIFFICULTY = {
    1: ([1, 1, 2, 2, 2], [2.0, 2.0, 1.5, 1.5, 1.5], 9, [7.0, 7.5, 8.0, 8.25, 8.5]),
    2: ([1, 2, 2, 2, 3], [2.0, 1.5, 1.5, 1.0, 1.0], 3, [7.0, 7.5, 8.0, 8.5, 9.0]),
    3: ([2, 2, 2, 3, 3], [1.5, 1.0, 1.0, 1.0, 1.0], 2, [7.0, 7.75, 8.5, 9.0, 9.5]),
    4: ([2, 2, 3, 3, 4], [1.0, 1.0, 1.0, 1.0, 0.75], 1, [7.0, 7.75, 8.5, 9.25, 10.0]),
    5: ([2, 3, 3, 4, 4], [1.0, 1.0, 0.75, 0.75, 0.75], 1, [7.25, 8.0, 8.75, 9.5, 10.25]),
}
# Only hits scoring above this share of the song's hits are tapped (relative: some songs are denser than others).
MIN_SCORE_QUANTILE = 0.5
# The last quarter must be this much harder than the first (taps x speed; test_shipped_charts asks for 1.5).
RAMP = 1.7
PAIR_GAP = 0.5
PAIR_TOLERANCE = 0.06
PHASES = 5
MIN_PHASE_BEATS = 48
CAMERA_ROTATION = ["side", "diagonal", "side_high", "side", "side_far", "diagonal", "side_low"]


def hit_table(samples, bpm):
    """(time, score, standout, attack) of every loudness hit; score = sqrt(standout * attack)."""
    rms = envelope(samples)
    strength = onset_strength(rms)
    seconds_per_beat = 60.0 / bpm
    table = []
    for time_sec, _ in loudness_hits(samples):
        tap = strength_at(strength, time_sec)
        around = [strength_at(strength, time_sec + slot * seconds_per_beat) for slot in NEIGHBOUR_SLOTS]
        standout = tap / max(sum(around) / len(around), 1e-9)
        attack = attack_at(rms, time_sec)
        table.append((time_sec, math.sqrt(standout * attack), standout, attack))
    return table, rms


def fit_offset(table, bpm):
    """Bar line: the quarter-beat phase that most strong hits sit on, then the slot of the bar holding most."""
    strong = sorted(table, key=lambda row: -row[1])[:max(len(table) // 3, 8)]
    times = np.array([row[0] for row in strong])
    weights = np.array([row[1] for row in strong])
    slot = 15.0 / bpm
    best_phase, best_score = 0.0, -1.0
    for phase in np.arange(0.0, slot, 0.001):
        error = np.abs((times - phase) / slot - np.round((times - phase) / slot)) * slot
        score = weights[error < 0.025].sum()
        if score > best_score:
            best_phase, best_score = phase, score
    slots = np.round((times - best_phase) / slot).astype(int) % 16
    downbeat = int(np.argmax(np.bincount(slots, weights=weights, minlength=16)))
    return float((best_phase + downbeat * slot) % (16 * slot))


def bar_levels(rms, bpm, offset):
    bar_frames = 4 * 60.0 / bpm / FRAME_SEC
    first = int(offset / FRAME_SEC)
    count = int((len(rms) - first) / bar_frames)
    return [float(rms[int(first + i * bar_frames):int(first + (i + 1) * bar_frames)].mean()) for i in range(count)]


def quiet_bars(levels):
    """Bars clearly quieter than the bars around them: the near-silent bar the prompts put before each section."""
    result = []
    for index in range(4, len(levels) - 1):
        around = sorted(levels[max(index - 4, 0):index] + levels[index + 1:index + 5])
        if levels[index] < 0.7 * around[len(around) // 2]:
            result.append(index)
    return result


def sections_from_bars(levels, end_beat):
    """Sections start after quiet bars and where 4-bar loudness shifts; long ones split every 16 bars. Energy is
    relative to the song (its 10th..90th percentile bar loudness mapped to 0.2..1), so evenly loud songs still
    get calm and intense sections."""
    bars = int(end_beat // 4)
    starts = {0} | {index + 1 for index in quiet_bars(levels) if index + 1 < bars}
    blocks = [sum(levels[i:i + 4]) / len(levels[i:i + 4]) for i in range(0, bars, 4)]
    low, high = np.percentile(levels[:bars], 10), np.percentile(levels[:bars], 90)
    for index in range(1, len(blocks)):
        if abs(blocks[index] - blocks[index - 1]) > 0.15 * max(high, 1e-9):
            starts.add(index * 4)
    starts = sorted(start for start in starts if start < bars)
    merged = []
    for start in starts:
        if merged and start - merged[-1] < 4:
            continue
        merged.append(start)
    split = []
    for i, start in enumerate(merged):
        stop = merged[i + 1] if i + 1 < len(merged) else bars
        split += list(range(start, stop - 8, 16)) if stop - start > 24 else [start]
    sections = []
    for i, start in enumerate(split):
        stop = split[i + 1] if i + 1 < len(split) else bars
        level = sum(levels[start:stop]) / max(stop - start, 1)
        energy = round(0.2 + 0.8 * min(max((level - low) / max(high - low, 1e-9), 0.0), 1.0), 2)
        name = "drop" if energy >= 0.75 else "break" if energy <= 0.4 else "verse"
        sections.append((start * 4, name, energy))
    sections[0] = (-16, "intro", sections[0][2])
    return sections


def level_end(levels):
    loud = max(levels)
    last = max(i for i, level in enumerate(levels) if level > 0.45 * loud)
    return (last + 1) * 4


def choose_phases(sections, end_beat, palettes, speeds, quiet):
    """Phase 1 at beat 0; the others open right after quiet bars (the prompts' phase breaks), then at the biggest
    loudness rises, MIN_PHASE_BEATS apart and spread over the song."""
    after_quiet = {(index + 1) * 4 for index in quiet}
    candidates = []
    for i in range(1, len(sections)):
        beat = sections[i][0]
        if MIN_PHASE_BEATS <= beat <= end_beat - 32:
            candidates.append((beat in after_quiet, sections[i][2] - sections[i - 1][2], beat))
    candidates.sort(reverse=True)
    starts = [0]
    for _, _, beat in candidates:
        if len(starts) == PHASES:
            break
        if all(abs(beat - other) >= MIN_PHASE_BEATS for other in starts):
            starts.append(beat)
    starts.sort()
    return [(beat, palettes[i % len(palettes)], speeds[i]) for i, beat in enumerate(starts)]


def select_taps(table, bpm, offset, phases, difficulty, end_beat):
    per_bar, min_gap, pairs_from, _ = DIFFICULTY[difficulty]
    seconds_per_beat = 60.0 / bpm
    phase_starts = [beat for beat, _, _ in phases]
    accepted = {}
    partner = set()
    bar_counts = {}
    floor = float(np.quantile([row[1] for row in table], MIN_SCORE_QUANTILE))
    for time_sec, score, _, _ in sorted(table, key=lambda row: -row[1]):
        if score < floor:
            break
        beat = round((time_sec - offset) / seconds_per_beat, 4)
        if beat < FIRST_TAP_BEAT or beat > end_beat - 2.0:
            continue
        phase = max(i for i, start in enumerate(phase_starts) if start <= beat)
        bar = int(beat // 4)
        if bar_counts.get(bar, 0) >= per_bar[phase]:
            continue
        clashes = [other for other in accepted if abs(other - beat) < min_gap[phase]]
        if clashes:
            other = clashes[0]
            is_pair = (len(clashes) == 1 and phase >= pairs_from and other not in partner
                       and abs(abs(other - beat) - PAIR_GAP) <= PAIR_TOLERANCE)
            if not is_pair:
                continue
            first, second = sorted((other, beat))
            # The orb pattern puts the second tap exactly half a beat after the first.
            accepted.pop(other)
            accepted[first] = score
            accepted[round(first + PAIR_GAP, 4)] = score
            partner.update((first, round(first + PAIR_GAP, 4)))
            bar_counts[bar] = bar_counts.get(bar, 0) + 1
            continue
        accepted[beat] = score
        bar_counts[bar] = bar_counts.get(bar, 0) + 1
    return ramped(accepted, partner, phases, end_beat)


def ramped(accepted, partner, phases, end_beat):
    """Drops the weakest taps of the first quarter (never half of a pair) until the last quarter is RAMP times
    harder (tap count x speed), so the level gets harder toward the end even where the song's best hits thin out."""
    def speed(beat):
        return max(rate for start, _, rate in phases if start <= beat) if beat >= 0 else phases[0][2]

    def load(beats):
        return sum(speed(beat) for beat in beats)

    quarter = end_beat / 4.0
    taps = dict(accepted)
    first = sorted((score, beat) for beat, score in taps.items() if beat < quarter and beat not in partner)
    last = [beat for beat in taps if beat >= end_beat - quarter]
    while first and load(last) < RAMP * load([beat for beat in taps if beat < quarter]):
        taps.pop(first.pop(0)[1])
    return sorted(taps)


def track_layout(sections, end_beat):
    """Calm stretches get the helix, waves and banked turns; drops open with a loop and roll later on."""
    track, cursor = [(0, {"shape": "straight"})], 0
    helix_done, loops, rolls, turn_sign = False, 0, 0, 1
    bounds = [(start, sections[i + 1][0] if i + 1 < len(sections) else end_beat, energy)
              for i, (start, _, energy) in enumerate(sections)]
    for start, stop, energy in bounds:
        start = max(start, 8)
        if stop - start < 12 or start < cursor + 4:
            continue
        if energy >= 0.75 and loops < 3:
            shape, length, loops = {"shape": "loop", "lateral": 7 * turn_sign}, 12, loops + 1
        elif energy < 0.5 and not helix_done and stop - start >= 20:
            shape, length, helix_done = {"shape": "helix", "angle_deg": 360, "rise": 18}, 16, True
        elif energy >= 0.6 and rolls < 3 and stop - start >= 16:
            shape, length, rolls = {"shape": "roll", "roll_deg": 360 * turn_sign}, 8, rolls + 1
        elif stop - start >= 16:
            shape, length = {"shape": "wave", "amplitude": 2, "count": 2}, 12
        else:
            shape, length = {"shape": "turn", "angle_deg": 30 * turn_sign, "bank_deg": 20}, 8
        track += [(start, shape), (start + length, {"shape": "straight"})]
        cursor = start + length
        turn_sign = -turn_sign
    return track


def build(song):
    path = os.path.join(ROOT, song.get("dir", "assets/music"), song["id"] + ".mp3")
    samples = decode(path)
    table, rms = hit_table(samples, song["bpm"])
    offset = song.get("offset", fit_offset(table, song["bpm"]))
    levels = bar_levels(rms, song["bpm"], offset)
    end_beat = song.get("end_beat", level_end(levels))
    sections = sections_from_bars(levels, end_beat)
    speeds = DIFFICULTY[song["difficulty"]][3]
    phases = choose_phases(sections, end_beat, song["palettes"], speeds, quiet_bars(levels))
    taps = select_taps(table, song["bpm"], offset, phases, song["difficulty"], end_beat)
    header = {"speed": [{"beat": b, "units_per_beat": rate} for b, _, rate in phases],
              "sections": [{"beat": b, "energy": e} for b, _, e in sections], "end_beat": end_beat}
    warnings = []
    builder = Builder(header, taps, warnings)
    builder.build()
    for warning in warnings:
        print("WARN", warning)
    cameras = [(-8, "front", 0), (-2, "side", 4)] + [(b, CAMERA_ROTATION[i % len(CAMERA_ROTATION)], 2)
                                                     for i, (b, _, _) in enumerate(sections[1:])]
    vfx = [(b, "shockwave") for b, name, _ in sections[1:] if name == "drop"] + [(end_beat, "burst")]
    chart_song = dict(song, offset=round(offset, 4), end_beat=end_beat, phases=phases, sections=sections,
                      cameras=cameras, track=track_layout(sections, end_beat), vfx=vfx)
    steps = " ".join("%s:%s" % (("%.4f" % beat).rstrip("0").rstrip("."), name) for beat, name in builder.steps)
    write_chart(chart_song, steps)
    print("offset %.4f  end beat %d  phases %s  taps chosen %d" % (offset, end_beat,
          [(b, p) for b, p, _ in phases], len(taps)))
