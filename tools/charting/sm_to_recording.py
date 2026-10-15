"""Convert a StepMania / ArrowVortex .sm chart into a BeatGlide recording (time + lane per tap).

Usage: python tools/charting/sm_to_recording.py <song.sm> <out.recording.json> [--chart=N] [--song=res://...]

Chart in ArrowVortex (good BPM/offset detection and a waveform editor), then feed the recording to
tools/audio/draft_chart.py via the plan's "recording" key. Column i of the .sm becomes lane i; the plan's
"lane_actions" decides what each lane does. Taps (1), hold heads (2) and roll heads (4) count as taps.
`--chart=N` picks the N-th #NOTES block (default: the last one, usually the hardest).
"""
import json
import re
import sys

TAP_CHARACTERS = "124"


def strip_comments(text):
    return re.sub(r"//[^\n]*", "", text)


def read_tags(text):
    """Returns [(tag, value)] in file order; #NOTES can appear several times."""
    return [(m.group(1).upper(), m.group(2)) for m in re.finditer(r"#([A-Za-z]+):([^;]*);", text)]


def parse_bpms(value):
    changes = []
    for item in value.split(","):
        item = item.strip()
        if item:
            beat, bpm = item.split("=")
            changes.append((float(beat), float(bpm)))
    changes.sort()
    if not changes or changes[0][0] > 0.0:
        raise ValueError("#BPMS must start at beat 0")
    return changes


def beat_to_time(beat, bpms, offset):
    """StepMania: beat 0 happens at time -#OFFSET."""
    time_sec = -offset
    for index, (start, bpm) in enumerate(bpms):
        end = bpms[index + 1][0] if index + 1 < len(bpms) else float("inf")
        if beat <= start:
            break
        span = min(beat, end) - start
        time_sec += span * 60.0 / bpm
    return time_sec


def parse_notes(value):
    fields = value.split(":")
    if len(fields) < 6:
        raise ValueError("malformed #NOTES block")
    taps = []
    for measure_index, measure in enumerate(fields[5].split(",")):
        rows = [row.strip() for row in measure.strip().splitlines() if row.strip()]
        for row_index, row in enumerate(rows):
            beat = measure_index * 4.0 + row_index * 4.0 / len(rows)
            for lane, character in enumerate(row):
                if character in TAP_CHARACTERS:
                    taps.append((beat, lane))
    return fields[2].strip() or fields[1].strip(), taps


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    options = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    sm_path, out_path = args[0], args[1]
    with open(sm_path, encoding="utf-8", errors="replace") as handle:
        tags = read_tags(strip_comments(handle.read()))
    values = {tag: value for tag, value in tags if tag != "NOTES"}
    notes_blocks = [value for tag, value in tags if tag == "NOTES"]
    if not notes_blocks:
        raise SystemExit("no #NOTES block in %s" % sm_path)
    offset = float(values.get("OFFSET", "0") or 0)
    bpms = parse_bpms(values.get("BPMS", ""))
    chart_index = int(options.get("chart", len(notes_blocks) - 1))
    difficulty, beat_taps = parse_notes(notes_blocks[chart_index])
    taps = [{"time_sec": round(beat_to_time(beat, bpms, offset), 4), "lane": lane} for beat, lane in beat_taps]
    taps.sort(key=lambda t: t["time_sec"])
    recording = {"version": 1, "song": options.get("song", ""), "source": "sm:%s" % difficulty, "taps": taps}
    with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(recording, handle, indent="\t")
        handle.write("\n")
    print("SM %d taps from '%s' (%d BPM change(s), offset %.3f) -> %s" % (len(taps), difficulty, len(bpms),
                                                                         offset, out_path))


main()
