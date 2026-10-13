"""Build game SFX from owner-generated videos (Google Flow image-to-video with audio).

  python tools/audio/build_sfx.py [--ffmpeg PATH] [--source-dir DIR] [--out-dir DIR] [--catalog FILE] [--only ID,...]

Sources: art_source/sfx/<ID>_take<N>.<mp4|mov|webm|wav|mp3>  (IDs listed in tools/audio/sfx_spec.py)
Per ID: decode with ffmpeg (mono 44.1 kHz) → DC removal + 30 Hz high-pass → split into events by
envelope → keep up to MAX_VARIANTS cleanest events across takes → fades → loudness-normalize
(BS.1770 K-weighted max momentary loudness, -1 dBFS ceiling) → assets/audio/sfx/<ID>_<n>.wav.
Updates the catalog (status "generated"), writes assets/audio/sfx_manifest.json (provenance) and
tools/audio/out/sfx_review.html for listening. Optional per-ID overrides: art_source/sfx/cuts.json
  {"player.jump": {"cuts": {"player.jump_take1.mp4": [[0.42, 0.71], ...]}, "max_len": 0.6}}
Prompts: docs/design/sfx/sfx_video_prompts.md. Needs numpy + scipy and an ffmpeg binary.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

from sfx_spec import CATEGORIES, ROOT, SAMPLE_RATE, SFX_DIR, SOUNDS, catalog_entry, load_catalog, save_catalog

SR = SAMPLE_RATE
DEFAULT_FFMPEG = Path("D:/ffmpeg-8.1-essentials_build/bin/ffmpeg.exe")
SOURCE_EXTENSIONS = {".mp4", ".mov", ".webm", ".m4a", ".wav", ".mp3", ".ogg"}
MAX_VARIANTS = 4
CEILING_DB = -1.0
MAX_GAIN_DB = 30.0
# Per-category event shaping: max event length, merge gap (s) and fade-out (s).
SHAPES = {
    "stinger": dict(max_len=3.5, merge=0.6, fade_out=0.25),
    "fx": dict(max_len=1.6, merge=0.25, fade_out=0.12),
    "impact": dict(max_len=1.2, merge=0.15, fade_out=0.08),
}
DEFAULT_SHAPE = dict(max_len=0.9, merge=0.1, fade_out=0.04)


def k_weighting():
    """BS.1770 K-weighting filters (high shelf + high pass) at SR."""
    f0, gain, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    a = 10 ** (gain / 40)
    w0 = 2 * np.pi * f0 / SR
    alpha = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    sa = 2 * np.sqrt(a) * alpha
    shelf = ([a * ((a + 1) + (a - 1) * c + sa), -2 * a * ((a - 1) + (a + 1) * c), a * ((a + 1) + (a - 1) * c - sa)],
             [(a + 1) - (a - 1) * c + sa, 2 * ((a - 1) - (a + 1) * c), (a + 1) - (a - 1) * c - sa])
    f0, q = 38.13547087602444, 0.5003270373238773
    w0 = 2 * np.pi * f0 / SR
    alpha = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    high_pass = ([(1 + c) / 2, -(1 + c), (1 + c) / 2], [1 + alpha, -2 * c, 1 - alpha])
    return shelf, high_pass


KW = k_weighting()


def max_momentary_loudness(x):
    y = x
    for b, a in KW:
        y = signal.lfilter(b, a, y)
    block, hop = int(0.4 * SR), int(0.1 * SR)
    if len(y) < block:
        return -0.691 + 10 * np.log10(np.mean(y ** 2) * len(y) / block + 1e-12)
    return max(-0.691 + 10 * np.log10(np.mean(y[s:s + block] ** 2) + 1e-12) for s in range(0, len(y) - block + 1, hop))


def decode(ffmpeg, path, tmp_dir):
    out = Path(tmp_dir) / (path.name + ".wav")
    subprocess.run([str(ffmpeg), "-hide_banner", "-loglevel", "error", "-y", "-i", str(path), "-vn", "-ac", "1",
                    "-ar", str(SR), "-c:a", "pcm_s16le", str(out)], check=True)
    rate, data = wavfile.read(out)
    x = data.astype(np.float64) / 32768.0
    x -= np.mean(x)
    return signal.sosfilt(signal.butter(2, 30, btype="highpass", fs=SR, output="sos"), x)


def envelope_db(x, hop=0.005):
    h = int(hop * SR)
    n = len(x) // h
    return 20 * np.log10(np.sqrt((x[:n * h].reshape(n, h) ** 2).mean(1)) + 1e-9), hop


def split_events(x, merge, threshold_db=26.0, weak_db=14.0, min_len=0.04, pre=0.01, post=0.03):
    """Active regions within threshold_db of the clip peak; drops weak and truncated events."""
    db, hop = envelope_db(x)
    peak, floor = db.max(), max(np.percentile(db, 10), -100.0)
    active = db > peak - threshold_db
    runs, i = [], 0
    while i < len(db):
        if active[i]:
            j = i
            while j < len(db) and active[j]:
                j += 1
            if runs and (i - runs[-1][1]) * hop < merge:
                runs[-1][1] = j
            else:
                runs.append([i, j])
            i = j
        else:
            i += 1
    events = []
    for k, (s, e) in enumerate(runs):
        run_peak = db[s:e].max()
        if run_peak < peak - weak_db or (e - s) * hop < min_len:
            continue
        limit = runs[k + 1][0] - 2 if k + 1 < len(runs) else len(db)
        end = e
        while end < limit and db[end] > max(run_peak - 40, floor + 6):
            end += 1
        if s * hop < 0.01 and db[s] > run_peak - 20:
            continue  # sound already running when the clip starts
        if e * hop > len(db) * hop - 0.1:
            continue  # clip ends before the sound decays
        events.append((max(0.0, s * hop - pre), min(end * hop + post, limit * hop), float(run_peak)))
    return events


def shape_event(x, fade_out):
    fade_in = int(0.002 * SR)
    fade_out_n = int(min(fade_out * SR, len(x) // 3))
    y = x.copy()
    y[:fade_in] *= np.sin(np.linspace(0, np.pi / 2, fade_in)) ** 2
    y[-fade_out_n:] *= np.cos(np.linspace(0, np.pi / 2, fade_out_n)) ** 2
    return y


def normalize(x, target):
    before = max_momentary_loudness(x)
    peak = np.max(np.abs(x)) + 1e-12
    gain_db = min(target - before, CEILING_DB - 20 * np.log10(peak), MAX_GAIN_DB)
    y = x * 10 ** (gain_db / 20)
    return y, before, gain_db, max_momentary_loudness(y)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def sound_id_of(path):
    stem = path.stem
    return stem.split("_take")[0] if "_take" in stem else stem


def build_sound(sound_id, sources, overrides, ffmpeg, out_dir, tmp_dir):
    category = SOUNDS[sound_id]
    shape = dict(SHAPES.get(category, DEFAULT_SHAPE))
    shape.update({k: v for k, v in overrides.items() if k in ("max_len", "merge", "fade_out")})
    candidates = []
    for source in sources:
        audio = decode(ffmpeg, source, tmp_dir)
        cuts = overrides.get("cuts", {}).get(source.name)
        events = [(a, b, 0.0) for a, b in cuts] if cuts else split_events(audio, shape["merge"])
        for start, end, peak in events:
            end = min(end, start + shape["max_len"])
            clip = audio[int(start * SR):int(end * SR)]
            if len(clip) > int(0.02 * SR):
                candidates.append(dict(source=source, start=start, end=end, peak=peak, audio=clip))
    candidates.sort(key=lambda c: -c["peak"])
    chosen = sorted(candidates[:MAX_VARIANTS], key=lambda c: (c["source"].name, c["start"]))
    for old in out_dir.glob(sound_id + "_*.wav"):
        old.unlink()
    files, records = [], []
    for index, candidate in enumerate(chosen):
        shaped = shape_event(candidate["audio"], shape["fade_out"])
        normalized, before, gain, after = normalize(shaped, CATEGORIES[category]["target"])
        path = out_dir / ("%s_%d.wav" % (sound_id, index + 1))
        wavfile.write(path, SR, (np.clip(normalized, -1, 1) * 32767).astype(np.int16))
        files.append(path)
        records.append({"output": path.name, "source": candidate["source"].name, "start_sec": round(candidate["start"], 3),
                        "end_sec": round(candidate["end"], 3), "loudness_before": round(before, 2),
                        "gain_db": round(gain, 2), "loudness_after": round(after, 2), "sha256": sha256(path)})
    sources_info = [{"file": s.name, "sha256": sha256(s)} for s in sources]
    return files, {"sources": sources_info, "variants": records}


def write_review(path, catalog):
    rows = []
    for sound_id, entry in catalog["sounds"].items():
        players = "".join('<audio controls preload="none" src="%s"></audio>' %
                          (Path("../../..") / f.removeprefix("res://")).as_posix() for f in entry["files"])
        rows.append("<tr><td>%s</td><td>%s</td><td>%s</td></tr>" % (sound_id, entry["status"], players))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("<!doctype html><meta charset=utf-8><title>SFX review</title><style>body{font:14px sans-serif;"
                    "background:#120a2a;color:#dfe}td{padding:4px 10px}audio{height:28px;margin-right:6px}</style>"
                    "<h1>SFX review</h1><table>%s</table>" % "".join(rows), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg", default=str(DEFAULT_FFMPEG if DEFAULT_FFMPEG.exists() else shutil.which("ffmpeg")))
    parser.add_argument("--source-dir", default=str(ROOT / "art_source/sfx"))
    parser.add_argument("--out-dir", default=str(SFX_DIR))
    parser.add_argument("--only", default="")
    args = parser.parse_args()
    source_dir, out_dir = Path(args.source_dir), Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    overrides_path = source_dir / "cuts.json"
    overrides = json.loads(overrides_path.read_text(encoding="utf-8")) if overrides_path.exists() else {}
    grouped = {}
    for path in sorted(source_dir.glob("*")) if source_dir.exists() else []:
        if path.suffix.lower() not in SOURCE_EXTENSIONS:
            continue
        sound_id = sound_id_of(path)
        if sound_id not in SOUNDS:
            print("WARN unknown sound ID in file name: %s" % path.name)
            continue
        grouped.setdefault(sound_id, []).append(path)
    only = set(filter(None, args.only.split(",")))
    # Output outside the project (testing) cannot be referenced as res:// paths: skip catalog/manifest.
    dry_run = not out_dir.resolve().is_relative_to(ROOT)
    catalog = load_catalog()
    manifest_path = ROOT / "assets/audio/sfx_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}
    with tempfile.TemporaryDirectory() as tmp_dir:
        for sound_id, sources in sorted(grouped.items()):
            if only and sound_id not in only:
                continue
            files, record = build_sound(sound_id, sources, overrides.get(sound_id, {}), args.ffmpeg, out_dir, tmp_dir)
            if not files:
                print("WARN %s: no usable event found in %d source(s); kept previous sound" % (sound_id, len(sources)))
                continue
            print("BUILT %-16s %d variant(s) from %d source(s)" % (sound_id, len(files), len(sources)))
            for variant in record["variants"]:
                print("      %(output)s  %(source)s %(start_sec).3f-%(end_sec).3f s  %(loudness_before).1f -> "
                      "%(loudness_after).1f LUFS" % variant)
            if not dry_run:
                catalog["sounds"][sound_id] = catalog_entry(sound_id, files, "generated")
                manifest[sound_id] = record
    if dry_run:
        print("DRY RUN (output outside the project): catalog and manifest not updated")
        return
    save_catalog(catalog)
    manifest_path.write_text(json.dumps(dict(sorted(manifest.items())), indent="\t") + "\n", encoding="utf-8")
    write_review(ROOT / "tools/audio/out/sfx_review.html", catalog)
    missing = [s for s in SOUNDS if catalog["sounds"].get(s, {}).get("status") != "generated"]
    print("STILL PLACEHOLDER (%d): %s" % (len(missing), ", ".join(missing)))


main()
