"""Analyze a song for charting: BPM, beat offset, per-band onsets and per-bar energy.

Runs inside Blender's bundled Python (uses `aud` to decode MP3 and numpy), so no extra installs:
  blender -b --factory-startup -P tools/audio/analyze_song.py -- <song.mp3> <out.json>
Output JSON is consumed by tools/audio/draft_chart.py and by humans when writing charts.
"""
import json
import sys

import aud
import numpy as np

HOP = 512
N_FFT = 2048
BANDS = {"low": (30.0, 150.0), "mid": (150.0, 2500.0), "high": (5000.0, 14000.0)}
BPM_RANGE = (70.0, 190.0)
BPM_PRIOR_CENTER = 125.0


def load_mono(path):
    sound = aud.Sound(path)
    rate = int(sound.specs[0])
    data = sound.data()
    mono = data.mean(axis=1).astype(np.float32) if data.ndim == 2 else data.astype(np.float32)
    return mono, rate


def stft_magnitude(signal, rate):
    window = np.hanning(N_FFT).astype(np.float32)
    frame_count = 1 + (len(signal) - N_FFT) // HOP
    frames = np.lib.stride_tricks.as_strided(
        signal, shape=(frame_count, N_FFT), strides=(signal.strides[0] * HOP, signal.strides[0]))
    spectrum = np.abs(np.fft.rfft(frames * window, axis=1))
    freqs = np.fft.rfftfreq(N_FFT, 1.0 / rate)
    return spectrum, freqs


def flux(log_spec):
    diff = np.diff(log_spec, axis=0, prepend=log_spec[:1])
    env = np.maximum(diff, 0.0).sum(axis=1)
    env -= np.convolve(env, np.ones(16) / 16.0, mode="same")  # remove slow trend
    env = np.maximum(env, 0.0)
    peak = env.max()
    return env / peak if peak > 0 else env


def sample_env(env, times, frame_rate):
    idx = times * frame_rate
    valid = (idx >= 0) & (idx < len(env) - 1)
    idx = idx[valid]
    lo = np.floor(idx).astype(int)
    frac = idx - lo
    return env[lo] * (1 - frac) + env[lo + 1] * frac


def comb_score(env, frame_rate, bpm, duration):
    """Best phase and score of a beat grid at `bpm` against the onset envelope."""
    period = 60.0 / bpm
    best = (0.0, -1.0)
    for phase in np.arange(0.0, period, 1.0 / frame_rate):
        beats = np.arange(phase, duration, period)
        score = sample_env(env, beats, frame_rate).mean()
        if score > best[1]:
            best = (phase, score)
    return best


def estimate_tempo(env, frame_rate, duration):
    # Coarse: autocorrelation with a log-normal prior around BPM_PRIOR_CENTER.
    ac = np.correlate(env, env, mode="full")[len(env) - 1:]
    candidates = []
    for bpm in np.arange(BPM_RANGE[0], BPM_RANGE[1], 0.5):
        lag = 60.0 / bpm * frame_rate
        lo = int(lag)
        value = ac[lo] * (1 - (lag - lo)) + ac[lo + 1] * (lag - lo)
        prior = np.exp(-0.5 * (np.log2(bpm / BPM_PRIOR_CENTER) / 0.6) ** 2)
        candidates.append((value * prior, bpm))
    candidates.sort(reverse=True)
    coarse = candidates[0][1]
    # Fine: comb search around the coarse value, then prefer an integer BPM when nearly as good.
    fine = max(((comb_score(env, frame_rate, b, duration)[1], b)
                for b in np.arange(coarse - 1.5, coarse + 1.5, 0.02)))
    integer_bpm = round(fine[1])
    integer_score = comb_score(env, frame_rate, integer_bpm, duration)[1]
    bpm = float(integer_bpm) if integer_score >= fine[0] * 0.97 else float(fine[1])
    return bpm


def pick_peaks(env, frame_rate, threshold, min_gap_sec):
    peaks = []
    last = -1e9
    for i in range(1, len(env) - 1):
        if env[i] >= threshold and env[i] >= env[i - 1] and env[i] > env[i + 1]:
            t = i / frame_rate
            if t - last >= min_gap_sec:
                peaks.append([round(t, 4), round(float(env[i]), 3)])
                last = t
    return peaks


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    song_path, out_path = args[0], args[1]
    signal, rate = load_mono(song_path)
    duration = len(signal) / rate
    frame_rate = rate / HOP

    spectrum, freqs = stft_magnitude(signal, rate)
    log_spec = np.log1p(spectrum * 10.0)
    full_env = flux(log_spec)
    band_envs = {}
    for name, (f_lo, f_hi) in BANDS.items():
        mask = (freqs >= f_lo) & (freqs < f_hi)
        band_envs[name] = flux(log_spec[:, mask])

    bpm = estimate_tempo(full_env, frame_rate, duration)
    period = 60.0 / bpm
    phase, _ = comb_score(full_env, frame_rate, bpm, duration)

    # Downbeat: the beat-in-bar position (0..3) with the strongest low-band (kick) energy.
    beats = np.arange(phase, duration, period)
    kick = sample_env(band_envs["low"], beats, frame_rate)
    bar_scores = [kick[k::4].mean() for k in range(4)]
    downbeat_index = int(np.argmax(bar_scores))
    offset = float(beats[downbeat_index])

    # Per-bar RMS energy (for section detection), bars counted from the offset.
    rms_frame = np.sqrt(np.convolve(signal ** 2, np.ones(HOP) / HOP, mode="same")[::HOP])
    bar_len = period * 4
    bars = []
    bar_start = offset
    bar_number = 0
    while bar_start < duration:
        a, b = int(bar_start * frame_rate), int(min(bar_start + bar_len, duration) * frame_rate)
        if b > a:
            bars.append({
                "bar": bar_number, "beat": bar_number * 4, "time": round(bar_start, 3),
                "rms": round(float(rms_frame[a:b].mean()), 4),
                "low": round(float(band_envs["low"][a:b].mean()), 4),
                "high": round(float(band_envs["high"][a:b].mean()), 4),
            })
        bar_start += bar_len
        bar_number += 1

    result = {
        "song": song_path, "duration_sec": round(duration, 3), "sample_rate": rate,
        "bpm": bpm, "offset_sec": round(offset, 4), "beat_phase_sec": round(float(phase), 4),
        "downbeat_scores": [round(float(s), 4) for s in bar_scores],
        "onsets": {name: pick_peaks(env, frame_rate, 0.25, 0.09) for name, env in band_envs.items()},
        "bars": bars,
    }
    with open(out_path, "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=1)
    print("ANALYSIS bpm=%.2f offset=%.4f duration=%.2f bars=%d" % (bpm, offset, duration, len(bars)))


main()
