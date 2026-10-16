"""Build and validate content packages; upload only through the backend publisher.
Usage: python tools/content/publish_song.py pulse_drive --version 2 --backend D:/sntgames-api [--license-verified]
(--license-verified: production CDN instead of encrypted staging).
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
# --license-verified only once the owner has confirmed commercial rights and kept the evidence (art_source/licenses/).
UNCONFIRMED_LICENSE = {"status": "unconfirmed", "distribution": "private_test_only"}
VERIFIED_LICENSE = {"status": "verified", "distribution": "commercial", "source": "Google Flow Music (member plan)"}
GODOT = os.environ.get("GODOT", "D:/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe")


def check(command, required=None):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, encoding="utf-8", errors="replace")
    output = result.stdout + result.stderr
    if result.returncode or "SCRIPT ERROR" in output or (required and not re.search(required, output)):
        raise RuntimeError("Validation failed: " + " ".join(command) + "\n" + output[-5000:])
    return output


def build(song_id, version, with_led=False, license_verified=False):
    if not re.fullmatch(r"[a-z0-9_]+", song_id) or version < 1:
        raise ValueError("Invalid ID or version")
    # Download-only songs live in assets/music/remote (left out of the APK and of the shipped song list).
    music = ROOT / "assets/music"
    if not (music / (song_id + ".chart.json")).exists():
        music = music / "remote"
    sources = [music / (song_id + ".chart.json")]
    variant = music / (song_id + "_led.chart.json")
    if with_led and variant.exists():
        sources.append(variant)
    directory = ROOT / "tools/content/staging" / song_id / str(version)
    directory.mkdir(parents=True, exist_ok=True)
    originals = []
    for source in sources:
        chart = json.loads(source.read_text())
        originals.append(dict(chart))
        check([sys.executable, "tools/charting/tap_salience.py", str(source)], r"\bOK\s*$")
        report = check([GODOT, "--headless", "--path", str(ROOT), "-s",
                        "res://tools/charting/tolerance_report.gd", "--", "--chart=res://" + source.relative_to(ROOT).as_posix()],
                       r"TOLERANCE cues=\d+ worst=\d+ ms")
        (directory / (source.stem + ".tolerance.txt")).write_text(report)
        chart["song"] = "song.mp3"
        chart["chart_revision"] = version
        (directory / source.name).write_text(json.dumps(chart, ensure_ascii=False))
    audio = ROOT / originals[0]["song"].removeprefix("res://")
    shutil.copyfile(audio, directory / "song.mp3")
    shutil.copyfile(audio.with_suffix(".spectrum.json"), directory / "song.spectrum.json")
    shutil.copyfile(ROOT / "assets/covers" / (song_id + ".jpg"), directory / "cover.jpg")
    chart_paths = ["res://" + (directory / source.name).relative_to(ROOT).as_posix() for source in sources]
    report = check([GODOT, "--headless", "--path", str(ROOT), "-s", "res://tools/content/validate_package.gd", "--", *chart_paths],
                   r"PACKAGE_AUTOPLAY_OK")
    scores = {data["chart"]: data["difficulty"] for line in report.splitlines() if line.startswith("PACKAGE_METADATA ")
              for data in [json.loads(line.removeprefix("PACKAGE_METADATA "))]}
    files = []
    for path in sorted(directory.iterdir()):
        if path.name not in [source.name for source in sources] + ["song.mp3", "song.spectrum.json", "cover.jpg"]:
            continue
        payload = path.read_bytes()
        key = f"private-encrypted/staging/{song_id}/{version}/{path.name}.aesgcm"
        files.append({"name": path.name, "size": len(payload), "sha256": hashlib.sha256(payload).hexdigest(),
                      "key": key, "url": "https://api.sntgames.com/v1/beatglide/staging/files/" + key})
    entries = []
    for source, original in zip(sources, originals):
        bpm = original["tempo"][0]["bpm"]
        entries.append({"id": source.name.removesuffix(".chart.json"), "package_id": song_id,
                        "title": original.get("title", song_id), "artist": original.get("artist", ""),
                        "bpm": bpm, "length": original["end_beat"] * 60 / bpm, "difficulty": scores[source.name],
                        "version": version, "schema_version": 1, "min_app_version": "1.0.0", "enabled": True,
                        "featured": False, "order": 100000, "unlock": "existing_chain",
                        "license": VERIFIED_LICENSE if license_verified else UNCONFIRMED_LICENSE,
                        "chart": source.name, "files": files, "size": sum(f["size"] for f in files)})
    (directory / "package.json").write_text(json.dumps(entries, ensure_ascii=False, indent=2))
    (directory / "validation.json").write_text(json.dumps({"checks": ["salience", "tolerance", "full_autoplay"],
        "hashes": {f["name"]: f["sha256"] for f in files}}))
    return directory


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("song_id")
    parser.add_argument("--version", required=True, type=int)
    parser.add_argument("--backend", type=Path)
    parser.add_argument("--with-led", action="store_true")
    parser.add_argument("--license-verified", action="store_true", help="owner confirmed commercial rights")
    args = parser.parse_args()
    directory = build(args.song_id, args.version, args.with_led, args.license_verified)
    print("Validated package:", directory)
    if args.backend:
        production = ["--production"] if args.license_verified else []
        subprocess.run([str(args.backend / ".venv/Scripts/python.exe"), str(args.backend / "tools/publish.py"), str(directory),
                        *production], check=True)


if __name__ == "__main__":
    main()
