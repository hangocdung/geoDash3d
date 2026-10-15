"""Synthesize placeholder SFX so the game has audio feedback before the real sounds exist.

  python tools/audio/synth_placeholder_sfx.py [--force]

Writes assets/audio/sfx/placeholder/<id>_<n>.wav (mono PCM16, 44.1 kHz) and marks the catalog
entries `status: placeholder`. IDs already built from real sources (status `generated`) are left
alone unless --force is given. Since GD3-258 the placeholders are a synthesized drum kit (the same roles as the
drum prompts in docs/design/sfx/sfx_video_prompts.md), normalized to the same loudness targets as build_sfx.py.
Needs numpy + scipy only.
"""
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

from build_sfx import normalize
from sfx_spec import SAMPLE_RATE, SFX_DIR, SOUNDS, catalog_entry, load_catalog, save_catalog, target_lufs

SR = SAMPLE_RATE
RNG = np.random.default_rng(7)
# Taps and landings repeat the most: more variants so they do not sound like a loop.
VARIANTS = {"player.jump": 3, "player.land": 3, "player.dodge": 3}


def t_axis(duration):
    return np.arange(int(duration * SR)) / SR


def env(duration, attack=0.001, decay=0.08):
    t = t_axis(duration)
    return np.minimum(t / attack, 1.0) * np.exp(-t / decay)


def noise(duration):
    return RNG.uniform(-1, 1, int(duration * SR))


def band(x, low, high):
    sos = signal.butter(2, [low, min(high, SR / 2 - 100)], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, cutoff):
    return signal.sosfilt(signal.butter(2, cutoff, btype="lowpass", fs=SR, output="sos"), x)


def mix(*parts):
    length = max(len(p) for p in parts)
    out = np.zeros(length)
    for p in parts:
        out[:len(p)] += p
    return out


def at(seconds, x):
    return np.concatenate([np.zeros(int(seconds * SR)), x])


def drum(f_start, f_end, pitch_decay, amp_decay, duration):
    """Membrane: a sine whose pitch drops from f_start to f_end, with an exponential amplitude decay."""
    t = t_axis(duration)
    freq = f_end + (f_start - f_end) * np.exp(-t / pitch_decay)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR) * env(duration, 0.0008, amp_decay)


def kick(k, decay=0.1, duration=0.32):
    return mix(drum(150 * k, 48 * k, 0.03, decay, duration), band(noise(0.006), 2000, 8000) * 0.25)


def snare(k, tone_decay=0.05, noise_decay=0.07, duration=0.22):
    tone = drum(260 * k, 190 * k, 0.02, tone_decay, duration) * 0.7 + drum(400 * k, 330 * k, 0.02, tone_decay * 0.6,
                                                                           duration) * 0.3
    rattle = band(noise(duration), 1500, 9000) * env(duration, 0.0005, noise_decay)
    return mix(tone * 0.8, rattle)


def rimshot(k):
    ring = (np.sin(2 * np.pi * 470 * k * t_axis(0.1)) + 0.5 * np.sin(2 * np.pi * 1650 * k * t_axis(0.1))) \
        * env(0.1, 0.0005, 0.018)
    return mix(band(noise(0.004), 1500, 6000), ring * 0.8, snare(k, 0.03, 0.035, 0.14) * 0.6)


def clap(k):
    bursts = [at(offset, band(noise(0.008), 900 * k, 3500 * k) * env(0.008, 0.0005, 0.004)) for offset in
              (0.0, 0.011, 0.022)]
    tail = at(0.025, band(noise(0.18), 900 * k, 3500 * k) * env(0.18, 0.001, 0.05))
    return mix(*bursts, tail * 0.8)


def tom(f, k, decay=0.16, duration=0.3):
    return mix(drum(f * 1.6 * k, f * k, 0.03, decay, duration), band(noise(0.01), 1000, 5000) * 0.15)


def hat(decay=0.03, duration=0.08):
    return band(noise(duration), 6000, 15000) * env(duration, 0.0005, decay)


def cymbal(decay, duration, k=1.0):
    t = t_axis(duration)
    metal = sum(np.sign(np.sin(2 * np.pi * f * k * t)) for f in (263, 400, 421, 474, 587, 845)) / 6
    return band(metal * 0.6 + noise(duration), 3500, 15000) * env(duration, 0.001, decay)


def clave(f):
    return np.sin(2 * np.pi * f * t_axis(0.12)) * env(0.12, 0.0005, 0.025)


def woodblock(f):
    t = t_axis(0.12)
    return (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 1.7 * t)) * env(0.12, 0.0005, 0.03)


def bell(k):
    t = t_axis(0.6)
    return sum(np.sin(2 * np.pi * f * k * t) * a for f, a in ((740, 1.0), (1180, 0.6), (1620, 0.4), (2600, 0.25))) \
        * env(0.6, 0.001, 0.2)


def taiko(k, decay=0.28, duration=0.7):
    return mix(drum(110 * k, 58 * k, 0.05, decay, duration),
               lowpass(noise(duration), 800) * env(duration, 0.001, 0.05) * 0.4)


def stick_click(k):
    return mix(band(noise(0.003), 2500, 7000), np.sin(2 * np.pi * 3200 * k * t_axis(0.03)) * env(0.03, 0.0003, 0.006))


def make(sound_id, variant):
    k = 1.0 + 0.03 * variant  # small per-variant pitch shift (the noise differs per call too)
    if sound_id == "player.jump":
        return rimshot(k)
    if sound_id == "player.land":
        return kick(k)
    if sound_id == "player.dodge":
        return clap(k)
    if sound_id == "player.flip":
        return mix(tom(210, k), at(0.085, tom(150, k)))
    if sound_id == "player.death":
        return mix(taiko(k), cymbal(0.5, 1.0, k) * 0.5, snare(k) * 0.6)
    if sound_id == "player.shield":
        return bell(k)
    if sound_id == "player.shield_break":
        choke = cymbal(0.25, 0.4, k)
        choke[int(0.16 * SR):] *= np.exp(-np.arange(len(choke) - int(0.16 * SR)) / (0.01 * SR))
        return mix(choke, snare(k) * 0.7)
    if sound_id == "judge.perfect":
        return clave(2500 * k)
    if sound_id == "judge.great":
        return woodblock(1100 * k) * 0.8
    if sound_id == "run.checkpoint":
        return mix(snare(k) * 0.5, at(0.025, snare(k)), at(0.03, cymbal(0.3, 0.6, k) * 0.35))
    if sound_id == "run.attempt":
        return mix(stick_click(k), at(0.14, stick_click(k)))
    if sound_id == "run.complete":
        fill = [at(0.1 * index, tom(f, k, 0.12, 0.25)) for index, f in enumerate((260, 210, 170, 130))]
        return mix(*fill, at(0.4, mix(kick(k, 0.15, 0.5), cymbal(0.9, 1.8, k) * 0.6, snare(k) * 0.5)))
    if sound_id == "hazard.rise":
        return hat()
    if sound_id == "hazard.drop":
        return tom(95, k, 0.2, 0.4)
    if sound_id == "hazard.unfold":
        roll = [at(index / 28.0, snare(k, 0.02, 0.02, 0.06) * (0.3 + 0.7 * index / 9)) for index in range(10)]
        return mix(*roll, at(0.36, rimshot(k)))
    if sound_id == "fx.shockwave":
        return mix(taiko(0.8 * k, 0.45, 1.0), lowpass(noise(1.0), 300) * env(1.0, 0.01, 0.3) * 0.5)
    if sound_id == "fx.flash":
        return cymbal(0.4, 0.5, k)[::-1].copy()
    if sound_id == "ui.tap":
        return stick_click(k)
    if sound_id == "ui.confirm":
        return mix(tom(180, k, 0.08, 0.15), at(0.07, tom(240, k, 0.1, 0.2)))
    if sound_id == "ui.back":
        return mix(tom(240, k, 0.08, 0.15), at(0.07, tom(180, k, 0.1, 0.2)))
    if sound_id == "ui.pause":
        return hat(0.08, 0.15)
    raise KeyError(sound_id)


def finish(x):
    x = x - np.mean(x)
    fade = min(len(x) // 4, int(0.01 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


def main():
    force = "--force" in sys.argv
    catalog = load_catalog()
    out_dir = SFX_DIR / "placeholder"
    out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    for sound_id in SOUNDS:
        current = catalog["sounds"].get(sound_id)
        if current and current.get("status") == "generated" and not force:
            continue
        for old in out_dir.glob(sound_id + "_*.wav"):
            old.unlink()
        files = []
        for variant in range(VARIANTS.get(sound_id, 2)):
            path = out_dir / ("%s_%d.wav" % (sound_id, variant + 1))
            audio, _, _, _ = normalize(finish(make(sound_id, variant)), target_lufs(sound_id))
            wavfile.write(path, SR, (np.clip(audio, -1, 1) * 32767).astype(np.int16))
            files.append(path)
        catalog["sounds"][sound_id] = catalog_entry(sound_id, files, "placeholder")
        written += 1
    save_catalog(catalog)
    print("PLACEHOLDER %d sound IDs written to %s" % (written, out_dir))


if __name__ == "__main__":
    main()
