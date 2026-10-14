"""Bar-by-bar grid of the hits that stand out, for hand-charting a new song: pick taps only on "X" slots and the
level passes tap_salience.py (the same two measures, per quarter-beat slot).

  bar  12  beat  44 | X . . . | . . x . | X . . . | . . . . |  peak x6.1
X = both measures pass (stands out from the slots within +-1 beat AND loud attack): tap here.
x = one passes (a weaker accent: fine for an orb or the second tap of a chain). . = nothing worth a tap.
The last line counts the bars that hold at least one X: a quick check of whether a new song suits the game.
Usage: python tools/charting/hit_grid.py <song.mp3> <bpm> <offset_sec> [first_bar] [last_bar]
       (BPM / offset from analyze_song.py; check that bar 1's first slot lands on the first big hit)
Related: tools/charting/tap_salience.py, docs/design/music_prompts.md, docs/chart_format.md
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loudness_onsets import FRAME_SEC, decode  # noqa: E402
from tap_salience import (GOOD_ATTACK, GOOD_STANDOUT, NEIGHBOUR_SLOTS, attack_at, envelope,  # noqa: E402
                          onset_strength, strength_at)

SLOTS_PER_BEAT = 4
BEATS_PER_BAR = 4


def slot_marks(strength, rms, time_sec, seconds_per_beat):
    tap = strength_at(strength, time_sec)
    around = [strength_at(strength, time_sec + slot * seconds_per_beat) for slot in NEIGHBOUR_SLOTS]
    standout = tap / max(sum(around) / len(around), 1e-9)
    attack = attack_at(rms, time_sec)
    passes = (standout >= GOOD_STANDOUT) + (attack >= GOOD_ATTACK)
    return ".xX"[passes], attack


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    song, bpm, offset = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
    rms = envelope(decode(song))
    strength = onset_strength(rms)
    seconds_per_beat = 60.0 / bpm
    duration = len(rms) * FRAME_SEC
    bars = int((duration - offset) / (seconds_per_beat * BEATS_PER_BAR))
    first = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    last = int(sys.argv[5]) if len(sys.argv) > 5 else bars - 1
    standout_bars = 0
    shown = 0
    for bar in range(first, min(last, bars - 1) + 1):
        groups = []
        peak = 0.0
        for beat_in_bar in range(BEATS_PER_BAR):
            marks = ""
            for slot in range(SLOTS_PER_BEAT):
                beat = bar * BEATS_PER_BAR + beat_in_bar + slot / SLOTS_PER_BEAT
                mark, attack = slot_marks(strength, rms, offset + beat * seconds_per_beat, seconds_per_beat)
                marks += mark + " "
                peak = max(peak, attack if mark != "." else 0.0)
            groups.append(marks.rstrip())
        print("bar %3d  beat %4d | %s |  peak x%.1f" % (bar, bar * BEATS_PER_BAR, " | ".join(groups), peak))
        shown += 1
        standout_bars += 1 if "X" in "".join(groups) else 0
    # Quick fitness check of a new song: the reference the_dawn_assembly has an X in most bars after its intro.
    print("bars with a tap-worthy hit (X): %d / %d (%.0f%%)" % (standout_bars, shown, 100.0 * standout_bars / max(shown, 1)))


if __name__ == "__main__":
    main()
