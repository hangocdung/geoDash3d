"""Shared SFX table: every sound ID with its category; categories carry bus, loudness target and playback hints.

Used by tools/audio/synth_placeholder_sfx.py and tools/audio/build_sfx.py, which both write
assets/audio/audio_catalog.json (read in game by src/core/audio/sfx.gd).
Prompts for generating the real sounds: docs/design/sfx/sfx_video_prompts.md.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG_PATH = ROOT / "assets/audio/audio_catalog.json"
SFX_DIR = ROOT / "assets/audio/sfx"
SAMPLE_RATE = 44100

# target = loudness in LUFS (max momentary, 400 ms); pitch = random pitch range; poly = max overlapping plays.
CATEGORIES = {
    "player":   dict(bus="SFX", target=-16.0, pitch=0.05, poly=2, volume_db=0.0),
    "impact":   dict(bus="SFX", target=-13.0, pitch=0.04, poly=2, volume_db=0.0),
    "judge":    dict(bus="SFX", target=-20.0, pitch=0.03, poly=3, volume_db=0.0),
    "hazard":   dict(bus="SFX", target=-19.0, pitch=0.06, poly=4, volume_db=0.0),
    "fx":       dict(bus="SFX", target=-15.0, pitch=0.0, poly=2, volume_db=0.0),
    "stinger":  dict(bus="SFX", target=-14.0, pitch=0.0, poly=1, volume_db=0.0),
    "ui":       dict(bus="UI", target=-21.0, pitch=0.02, poly=2, volume_db=0.0),
}

SOUNDS = {
    "player.jump": "player",
    "player.land": "player",
    "player.dodge": "player",
    "player.flip": "player",
    "player.death": "impact",
    "judge.perfect": "judge",
    "judge.great": "judge",
    "run.checkpoint": "judge",
    "run.attempt": "judge",
    "run.complete": "stinger",
    "hazard.rise": "hazard",
    "hazard.drop": "hazard",
    "hazard.unfold": "hazard",
    "fx.shockwave": "fx",
    "fx.flash": "fx",
    "ui.tap": "ui",
    "ui.confirm": "ui",
    "ui.back": "ui",
    "ui.pause": "ui",
}


def load_catalog():
    if CATALOG_PATH.exists():
        return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    return {"version": 1, "sounds": {}}


def save_catalog(catalog):
    CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    catalog["sounds"] = dict(sorted(catalog["sounds"].items()))
    CATALOG_PATH.write_text(json.dumps(catalog, indent="\t") + "\n", encoding="utf-8", newline="\n")


def catalog_entry(sound_id, files, status):
    category = CATEGORIES[SOUNDS[sound_id]]
    return {
        "files": ["res://" + Path(f).resolve().relative_to(ROOT).as_posix() for f in files],
        "bus": category["bus"],
        "volume_db": category["volume_db"],
        "pitch_random": category["pitch"],
        "max_polyphony": category["poly"],
        "status": status,
    }
