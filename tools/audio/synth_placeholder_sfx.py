"""Synthesize placeholder SFX so the game has audio feedback before the real sounds exist.

  python tools/audio/synth_placeholder_sfx.py [--force]

Writes assets/audio/sfx/placeholder/<id>_<n>.wav (mono PCM16, 44.1 kHz) and marks the catalog
entries `status: placeholder`. IDs already built from real sources (status `generated`) are left
alone unless --force is given. Needs numpy + scipy only.
"""
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

from sfx_spec import SAMPLE_RATE, SFX_DIR, SOUNDS, catalog_entry, load_catalog, save_catalog

SR = SAMPLE_RATE
RNG = np.random.default_rng(7)


def t_axis(duration):
    return np.arange(int(duration * SR)) / SR


def env(duration, attack=0.002, decay=0.08):
    t = t_axis(duration)
    return np.minimum(t / attack, 1.0) * np.exp(-t / decay)


def sweep(f0, f1, duration, shape="sine"):
    t = t_axis(duration)
    freq = f0 * (f1 / f0) ** (t / duration)
    phase = 2 * np.pi * np.cumsum(freq) / SR
    if shape == "square":
        return np.sign(np.sin(phase)) * 0.6
    if shape == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    return np.sin(phase)


def noise(duration):
    return RNG.uniform(-1, 1, int(duration * SR))


def band(x, low, high):
    sos = signal.butter(2, [low, high], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, cutoff):
    return signal.sosfilt(signal.butter(2, cutoff, btype="lowpass", fs=SR, output="sos"), x)


def mix(*parts):
    length = max(len(p) for p in parts)
    out = np.zeros(length)
    for p in parts:
        out[:len(p)] += p
    return out


def tones(freqs, duration, decay):
    t = t_axis(duration)
    return sum(np.sin(2 * np.pi * f * t) for f in freqs) / len(freqs) * env(duration, 0.002, decay)


def make(sound_id, variant):
    k = 1.0 + 0.04 * variant  # small per-variant pitch shift
    if sound_id == "player.jump":
        return mix(sweep(320 * k, 980 * k, 0.13) * env(0.13, 0.002, 0.06), band(noise(0.03), 2000, 8000) * 0.3)
    if sound_id == "player.land":
        return mix(sweep(140 * k, 55, 0.12) * env(0.12, 0.001, 0.04),
                   band(noise(0.04), 3000, 9000) * env(0.04, 0.001, 0.01) * 0.4)
    if sound_id == "player.dodge":
        return band(noise(0.16), 900 * k, 4000) * np.sin(np.linspace(0, np.pi, int(0.16 * SR))) ** 2 * 1.4
    if sound_id == "player.flip":
        whoosh = band(noise(0.3), 500 * k, 3000) * np.sin(np.linspace(0, np.pi, int(0.3 * SR))) ** 2 * 1.3
        clunk = np.concatenate([np.zeros(int(0.26 * SR)), sweep(220, 90, 0.08) * env(0.08, 0.001, 0.025)])
        return mix(whoosh, clunk)
    if sound_id == "player.death":
        shatter = band(noise(0.45), 2500, 9000) * env(0.45, 0.001, 0.12)
        crackle = (RNG.uniform(0, 1, int(0.45 * SR)) > 0.995) * RNG.uniform(-1, 1, int(0.45 * SR)) * env(0.45, 0.001, 0.2)
        zap = sweep(900 * k, 90, 0.3, "square") * env(0.3, 0.001, 0.1) * 0.5
        return mix(shatter, crackle * 0.8, zap)
    if sound_id == "judge.perfect":
        return tones([2637 * k, 3951 * k, 5274 * k, 6644 * k], 0.3, 0.07) * (1 + 0.3 * np.sin(2 * np.pi * 30 * t_axis(0.3)))
    if sound_id == "judge.great":
        return tones([1976 * k, 2960 * k], 0.2, 0.05) * 0.8
    if sound_id == "run.checkpoint":
        whoosh = lowpass(noise(0.3), 2500) * np.linspace(0, 1, int(0.3 * SR)) ** 2
        ping = np.concatenate([np.zeros(int(0.25 * SR)), tones([2093 * k, 4186 * k], 0.35, 0.09)])
        return mix(whoosh * 0.8, ping)
    if sound_id == "run.attempt":
        return np.concatenate([tones([f * k], 0.05, 0.02) for f in (880, 1175, 1568)])
    if sound_id == "run.complete":
        notes = [523.25, 659.25, 783.99, 1046.5]
        parts = [lowpass(sweep(f, f, 0.16, "saw"), 3000) * env(0.16, 0.003, 0.12) for f in notes[:-1]]
        final = lowpass(sweep(notes[-1], notes[-1], 1.2, "saw") + sweep(notes[-1] * 1.5, notes[-1] * 1.5, 1.2, "saw") * 0.5,
                        2600) * env(1.2, 0.005, 0.45)
        return np.concatenate(parts + [final]) * 0.7
    if sound_id == "hazard.rise":
        scrape = band(noise(0.16), 3000, 9000) * np.linspace(0.2, 1, int(0.16 * SR)) * env(0.16, 0.002, 0.2)
        return mix(scrape, np.concatenate([np.zeros(int(0.14 * SR)), tones([3520 * k], 0.06, 0.015)]))
    if sound_id == "hazard.drop":
        thud = sweep(95 * k, 40, 0.35) * env(0.35, 0.001, 0.12)
        clank = tones([410 * k, 913 * k, 1571 * k, 2290 * k], 0.4, 0.09) * 0.5
        return mix(thud, clank, band(noise(0.08), 200, 1200) * env(0.08, 0.001, 0.03))
    if sound_id == "hazard.unfold":
        hum = sweep(80 * k, 240 * k, 0.45, "saw") * np.linspace(0.1, 1, int(0.45 * SR)) * 0.35
        zap = np.concatenate([np.zeros(int(0.43 * SR)), band(noise(0.08), 2000, 8000) * env(0.08, 0.001, 0.025)])
        return mix(lowpass(hum, 1800), zap)
    if sound_id == "fx.shockwave":
        boom = sweep(70, 32, 0.8) * env(0.8, 0.003, 0.25)
        whoosh = lowpass(noise(0.8), 1500) * env(0.8, 0.02, 0.3) * 0.5
        return mix(boom, whoosh)
    if sound_id == "fx.flash":
        swell = band(noise(0.35), 1500, 9000) * np.linspace(0, 1, int(0.35 * SR)) ** 3
        return mix(swell, np.concatenate([np.zeros(int(0.35 * SR)), band(noise(0.12), 1000, 6000) * env(0.12, 0.001, 0.04)]))
    if sound_id == "ui.tap":
        return tones([1760 * k], 0.04, 0.012)
    if sound_id == "ui.confirm":
        return np.concatenate([tones([880 * k], 0.06, 0.03), tones([1318.5 * k], 0.12, 0.05)])
    if sound_id == "ui.back":
        return np.concatenate([tones([1318.5 * k], 0.06, 0.03), tones([880 * k], 0.1, 0.04)])
    if sound_id == "ui.pause":
        return lowpass(noise(0.18), 1200) * np.linspace(1, 0, int(0.18 * SR)) ** 2
    raise KeyError(sound_id)


def finish(x, peak_db):
    x = x - np.mean(x)
    fade = min(len(x) // 4, int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    peak = np.max(np.abs(x)) + 1e-9
    return x / peak * 10 ** (peak_db / 20)


def main():
    force = "--force" in sys.argv
    catalog = load_catalog()
    out_dir = SFX_DIR / "placeholder"
    out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    for sound_id, category in SOUNDS.items():
        current = catalog["sounds"].get(sound_id)
        if current and current.get("status") == "generated" and not force:
            continue
        peak_db = -9.0 if category == "ui" else (-4.0 if category in ("impact", "fx", "stinger") else -6.0)
        files = []
        for variant in range(2):
            path = out_dir / ("%s_%d.wav" % (sound_id, variant + 1))
            wavfile.write(path, SR, (finish(make(sound_id, variant), peak_db) * 32767).astype(np.int16))
            files.append(path)
        catalog["sounds"][sound_id] = catalog_entry(sound_id, files, "placeholder")
        written += 1
    save_catalog(catalog)
    print("PLACEHOLDER %d sound IDs written to %s" % (written, out_dir))


main()
