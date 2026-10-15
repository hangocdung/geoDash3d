"""Level driven by the LED equalizer: the player taps where the LED wall on the road's side visibly jumps (many
bands rising at once, measured at 100 frames a second on the same bands as tools/audio/build_spectrum.py), and the
loud sections get bursts: runs of jumps half a beat, three quarters of a beat or one beat apart are kept whole
(orb triplets, stairs, jump chains) so the player taps continuously. Sections, phases, track shapes, cameras,
density per phase and the end ramp come from hit_level.py; the obstacles from recording_level.Builder.
Usage: a song script calls build(SONG) (see tools/charting/levels/pulse_drive_led.py).
Related: tools/charting/hit_level.py, tools/audio/build_spectrum.py, src/presentation/track/spectrum_texture.gd
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hit_level  # noqa: E402
from handmade import build as write_chart  # noqa: E402
from loudness_onsets import SAMPLE_RATE, decode, loudness_hits  # noqa: E402
from recording_level import Builder  # noqa: E402
from tap_salience import envelope  # noqa: E402

ROOT = hit_level.ROOT
HOP = 220
WINDOW = 1024
BANDS = 16
LOW_HZ, HIGH_HZ = 40.0, 11000.0
# A jump: how far the bands rise above their own maximum over the previous ~20-80 ms (LED bars shooting up).
RECENT_FRAMES = (8, 2)
PEAK_RADIUS = 10
# Only jumps in the top share of the song count.
JUMP_QUANTILE = 0.8
# Bursts: spacing (beats) between consecutive jumps, how close it must be, how many in a row, loud sections only.
BURST_GAPS = (0.5, 0.75, 1.0)
BURST_TOLERANCE = 0.07
BURST_LENGTH = 3
BURST_ENERGY = 0.6
# At most one burst every this many beats (they are the hard part, not the whole level).
BURST_SPACING = 8.0
# The spectral window reacts ~20 ms after a hit: each jump is moved onto the nearest loudness onset this close.
SNAP_SEC = 0.05
# Songs known to sit on their beat grid (SONG["grid"], e.g. 0.25) get jumps this close to a grid step snapped onto it.
GRID_TOLERANCE = 0.08


def led_jumps(samples):
    """(time, strength) of the moments the LED bands jump up the most."""
    frames = (len(samples) - WINDOW) // HOP
    window = np.hanning(WINDOW).astype(np.float32)
    frequencies = np.fft.rfftfreq(WINDOW, 1.0 / SAMPLE_RATE)
    edges = np.geomspace(LOW_HZ, HIGH_HZ, BANDS + 1)
    masks = [(frequencies >= edges[i]) & (frequencies < edges[i + 1]) for i in range(BANDS)]
    power = np.zeros((frames, BANDS), np.float32)
    for frame in range(frames):
        spectrum = np.abs(np.fft.rfft(samples[frame * HOP:frame * HOP + WINDOW] * window)) ** 2
        power[frame] = [spectrum[mask].mean() if mask.any() else 0.0 for mask in masks]
    decibels = 10.0 * np.log10(power + 1e-10)
    low, high = np.percentile(decibels, 10, axis=0), np.percentile(decibels, 99, axis=0)
    level = np.clip((decibels - low) / np.maximum(high - low, 1e-6), 0.0, 1.0) ** 1.4
    jump = np.zeros(frames, np.float32)
    for frame in range(RECENT_FRAMES[0], frames):
        recent = level[frame - RECENT_FRAMES[0]:frame - RECENT_FRAMES[1] + 1].max(0)
        jump[frame] = np.maximum(level[frame] - recent, 0.0).sum()
    floor = np.quantile(jump, JUMP_QUANTILE)
    peaks = []
    for frame in range(PEAK_RADIUS, frames - PEAK_RADIUS):
        if jump[frame] >= floor and jump[frame] == jump[frame - PEAK_RADIUS:frame + PEAK_RADIUS + 1].max():
            # The LED frame is centred on the window: the jump happens at the window's centre.
            peaks.append(((frame * HOP + WINDOW / 2) / SAMPLE_RATE, float(jump[frame])))
    return snapped_to_onsets(peaks, samples)


def snapped_to_onsets(peaks, samples):
    """Moves each jump onto the nearest loudness onset within SNAP_SEC (sample-accurate attack times); jumps
    without one keep their time plus the median shift of the others."""
    onsets = np.array([time_sec for time_sec, _ in loudness_hits(samples)])
    result, shifts = [], []
    for time_sec, strength in peaks:
        index = int(np.argmin(np.abs(onsets - time_sec))) if len(onsets) else -1
        if index >= 0 and abs(onsets[index] - time_sec) <= SNAP_SEC:
            shifts.append(onsets[index] - time_sec)
            result.append((float(onsets[index]), strength, True))
        else:
            result.append((time_sec, strength, False))
    shift = float(np.median(shifts)) if shifts else 0.0
    return [(time_sec if exact else time_sec + shift, strength) for time_sec, strength, exact in result]


def find_bursts(candidates, sections, phases):
    """Runs of BURST_LENGTH+ jumps at one of BURST_GAPS apart in loud sections (not in phase 1), snapped to exact
    multiples of that gap from the run's first beat (as the patterns need), strongest runs first, spread out."""
    def energy_at(beat):
        return max((e for b, _, e in sections if b <= beat), default=0.0)

    beats = sorted(candidates)
    runs = []
    for gap in BURST_GAPS:
        for start_index, start in enumerate(beats):
            run = [start]
            for beat in beats[start_index + 1:]:
                step = beat - run[-1]
                if abs(step - gap) <= BURST_TOLERANCE:
                    run.append(beat)
                elif step > gap + BURST_TOLERANCE:
                    break
                if len(run) == BURST_LENGTH:
                    break
            if len(run) == BURST_LENGTH and energy_at(start) >= BURST_ENERGY and start >= phases[1][0]:
                runs.append((sum(candidates[b] for b in run), gap, start))
    runs.sort(reverse=True)
    chosen = []
    for _, gap, start in runs:
        if all(abs(start - other) >= BURST_SPACING for _, other in chosen):
            chosen.append((gap, start))
    return [[round(start + k * gap, 4) for k in range(BURST_LENGTH)] for gap, start in sorted(chosen, key=lambda c: c[1])]


def select_taps(jumps, song, offset, phases, sections, end_beat):
    per_bar, min_gap, _, _ = hit_level.DIFFICULTY[song["difficulty"]]
    seconds_per_beat = 60.0 / song["bpm"]
    candidates = {}
    grid = song.get("grid", 0.0)
    for time_sec, strength in jumps:
        beat = round((time_sec - offset) / seconds_per_beat, 4)
        if grid > 0.0 and abs(beat - round(beat / grid) * grid) <= GRID_TOLERANCE:
            beat = round(round(beat / grid) * grid, 4)
        if hit_level.FIRST_TAP_BEAT <= beat <= end_beat - 4.0:
            candidates[beat] = strength
    bursts = find_bursts(candidates, sections, phases)
    accepted = {}
    locked = set()
    for run in bursts:
        for beat in run:
            accepted[beat] = 1e9
            locked.add(beat)
    phase_starts = [beat for beat, _, _ in phases]
    bar_counts = {}
    for beat, strength in sorted(candidates.items(), key=lambda item: -item[1]):
        phase = max(i for i, start in enumerate(phase_starts) if start <= beat)
        bar = int(beat // 4)
        if bar_counts.get(bar, 0) >= per_bar[phase]:
            continue
        if any(abs(other - beat) < min_gap[phase] for other in accepted):
            continue
        accepted[beat] = strength
        bar_counts[bar] = bar_counts.get(bar, 0) + 1
    return hit_level.ramped(accepted, locked, phases, end_beat), bursts


def build(song):
    samples = decode(os.path.join(ROOT, "assets", "music", song["audio"] + ".mp3"))
    rms = envelope(samples)
    offset = song["offset"]
    levels = hit_level.bar_levels(rms, song["bpm"], offset)
    end_beat = song.get("end_beat", hit_level.level_end(levels))
    sections = hit_level.sections_from_bars(levels, end_beat)
    phases = hit_level.choose_phases(sections, end_beat, song["palettes"],
                                     hit_level.DIFFICULTY[song["difficulty"]][3], hit_level.quiet_bars(levels))
    taps, bursts = select_taps(led_jumps(samples), song, offset, phases, sections, end_beat)
    header = {"speed": [{"beat": b, "units_per_beat": rate} for b, _, rate in phases],
              "sections": [{"beat": b, "energy": e} for b, _, e in sections], "end_beat": end_beat}
    warnings = []
    builder = Builder(header, taps, warnings)
    builder.build()
    for warning in warnings:
        print("WARN", warning)
    cameras = [(-8, "front", 0), (-2, "side", 4)] + [(b, hit_level.CAMERA_ROTATION[i % len(hit_level.CAMERA_ROTATION)], 2)
                                                     for i, (b, _, _) in enumerate(sections[1:])]
    vfx = [(b, "shockwave") for b, name, _ in sections[1:] if name == "drop"] + [(end_beat, "burst")]
    chart_song = dict(song, end_beat=end_beat, phases=phases, sections=sections, cameras=cameras,
                      track=hit_level.track_layout(sections, end_beat), vfx=vfx)
    steps = " ".join("%s:%s" % (("%.4f" % beat).rstrip("0").rstrip("."), name) for beat, name in builder.steps)
    write_chart(chart_song, steps)
    print("bursts %d: %s" % (len(bursts), ", ".join("%g+%g" % (run[0], run[1] - run[0]) for run in bursts)))
    print("phases %s  taps chosen %d" % ([(b, p) for b, p, _ in phases], len(taps)))
