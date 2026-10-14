"""Phrase-based levels: taps on the half-beat grid AND on the loudest hits, with one rhythm motif per section.

Like the hand-made first level: every tap sits on the beat grid, lands on a moment where the whole mix jumps
louder, and the same rhythm repeats phrase after phrase so it can be anticipated. Per section, each half-beat
slot of a 16-beat phrase is scored by the median loudness jump at that slot over the section's phrases; the
loudest slots (spaced by the section's minimum gap) form the motif, applied to every phrase. Terrain patterns
rotate over the motif; handmade.Checker validates everything (landing, heights, flat road).
Usage: a song script calls build_phrase_level(SONG, SECTION_RULES) (see tools/charting/levels/*_phrase.py).
Related: tools/charting/handmade.py, tools/charting/loudness_onsets.py
"""
import math

import numpy as np

from handmade import build
from terrain_patterns import fall_beats
from loudness_onsets import AFTER_FRAMES, BEFORE, FRAME_SEC, HOP, decode

PHRASE_BEATS = 16
SLOT = 0.5
WINDOW_SEC = 0.03


class LoudnessEnvelope:
    def __init__(self, song_path):
        samples = decode(song_path)
        frames = len(samples) // HOP
        self.level = 10.0 * np.log10((samples[:frames * HOP].reshape(-1, HOP) ** 2).mean(1) + 1e-10)

    def jump(self, time_sec):
        """Largest loudness jump (dB) starting within WINDOW_SEC of `time_sec`."""
        best = 0.0
        center = int(time_sec / FRAME_SEC)
        reach = int(WINDOW_SEC / FRAME_SEC)
        for i in range(center - reach, center + reach + 1):
            if i < BEFORE[1] or i + AFTER_FRAMES >= len(self.level):
                continue
            best = max(best, self.level[i:i + AFTER_FRAMES].max() - self.level[i - BEFORE[1]:i - BEFORE[0]].mean())
        return best


def motif(envelope, song, start, end, rule):
    """Half-beat offsets (within a phrase) of the loudest slots, spaced by rule['gap'], at most rule['taps']."""
    spb = 60.0 / song["bpm"]
    phrases = [p for p in np.arange(start, end - PHRASE_BEATS + 0.01, PHRASE_BEATS)]
    if not phrases:
        phrases = [start]
    scores = []
    for slot in np.arange(0.0, PHRASE_BEATS, SLOT):
        values = [envelope.jump(song["offset"] + (p + slot) * spb) for p in phrases if p + slot < end - 1.0]
        scores.append((float(np.median(values)) if values else 0.0, float(slot)))
    chosen = []
    for score, slot in sorted(scores, reverse=True):
        if len(chosen) >= rule["taps"] or score < rule.get("min_db", 6.0):
            break
        # Keep the gap inside the phrase and across the phrase boundary (motifs repeat back to back).
        if all(min(abs(slot - c), PHRASE_BEATS - abs(slot - c)) >= rule["gap"] - 1e-6 for c in chosen):
            chosen.append(slot)
    return sorted(chosen)


def verify_taps(envelope, song, taps, rule):
    """Keep each motif tap only where this phrase is really loud there; else nudge it half a beat or drop it."""
    spb = 60.0 / song["bpm"]
    keep_db = rule.get("keep_db", rule.get("min_db", 6.0))
    kept = []
    for index, beat in enumerate(taps):
        following = taps[index + 1] if index + 1 < len(taps) else math.inf
        for candidate in (beat, beat - SLOT, beat + SLOT):
            clear = (not kept or candidate - kept[-1] >= rule["gap"] - 1e-6) and following - candidate >= rule["gap"] - 1e-6
            if clear and envelope.jump(song["offset"] + candidate * spb) >= keep_db:
                kept.append(candidate)
                break
    return kept


def plan_steps(song, rules, envelope):
    """Steps text for handmade.build: motif taps per section with rotating patterns and drops."""
    steps = []
    height = 0.0
    rotation = 0
    report = []
    sections = rules
    for index, rule in enumerate(sections):
        start, end = rule["start"], rule["end"]
        slots = motif(envelope, song, start, end, rule)
        report.append("%5.0f-%-5.0f gap %.2f -> motif %s" % (start, end, rule["gap"], slots))
        taps = []
        for phrase in np.arange(start, end, PHRASE_BEATS):
            taps += [phrase + s for s in slots if phrase + s < end - 0.5]
        taps = verify_taps(envelope, song, taps, rule)
        # Taps half a beat apart become one orb move (jump + orb taps): orb for two, trip for three.
        runs = []
        for beat in taps:
            if runs and abs(beat - runs[-1][-1] - SLOT) < 1e-6 and len(runs[-1]) < 3:
                runs[-1].append(beat)
            else:
                runs.append([beat])
        for i, run in enumerate(runs):
            beat = run[0]
            gap_next = runs[i + 1][0] - beat if i + 1 < len(runs) else 8.0
            if len(run) > 1:
                name = "orb" if len(run) == 2 else "trip"
                if height + (2.0 if len(run) == 2 else 4.0) > 6.0 or gap_next < len(run) * SLOT + 1.0:
                    # No room to climb: keep the first tap only.
                    name = "spike" if gap_next >= 1.0 else "gap"
            else:
                singles = [n for n in rule["patterns"] if n != "orb"]
                name = singles[rotation % len(singles)]
                rotation += 1
                # Lane actions need the road and enough time; otherwise a spike.
                if name in ("dl", "dr", "flip") and (height > 0.0 or gap_next < (2.0 if name == "flip" else 1.25)):
                    name = "spike"
                if name == "step" and height >= 4.0:
                    name = "gap"
            steps.append((beat, name))
            height += {"step": 1.5, "orb": 2.0, "trip": 4.0}.get(name, 0.0)
            # Come back down where there is room before the next tap (after landing, before the next take-off).
            busy = {"orb": 1.5, "trip": 2.0}.get(name, 1.0)
            if height >= 3.0 and gap_next >= busy + fall_beats(height) + 0.25:
                steps.append((beat + busy, "drop"))
                height = 0.0
    return steps, report


def build_phrase_level(song, rules):
    envelope = LoudnessEnvelope(song["path"])
    steps, report = plan_steps(song, rules, envelope)
    print("\n".join(report))
    text = " ".join("%s:%s" % (("%.4f" % beat).rstrip("0").rstrip("."), name) for beat, name in steps)
    build(song, text)
