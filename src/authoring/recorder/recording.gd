# Raw tap recording for charting: taps stored as song time + lane, quantized only when drafting
# the chart (tools/audio/draft_chart.py), so a recording survives tempo/offset fixes.
# File: assets/music/<id>.recording.json. Related: recorder.gd, tools/charting/sm_to_recording.py
class_name Recording
extends RefCounted

const VERSION: int = 1

## Sorted by time.
var tap_times: PackedFloat64Array = []
var tap_lanes: PackedInt32Array = []
var song_path: String = ""


static func path_for_chart(chart_path: String) -> String:
	return chart_path.trim_suffix(".chart.json") + ".recording.json"


static func load_file(path: String) -> Recording:
	var recording := Recording.new()
	if not FileAccess.file_exists(path):
		return recording
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Recording: '%s' is not a JSON object" % path)
		return recording
	var root: Dictionary = data as Dictionary
	recording.song_path = str(root.get("song", ""))
	for entry: Variant in root.get("taps", []) as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var tap: Dictionary = entry as Dictionary
		recording.add_tap(float(tap.get("time_sec", 0.0)), int(tap.get("lane", 0)))
	return recording


func save_file(path: String) -> Error:
	var taps: Array[Dictionary] = []
	for index: int in tap_times.size():
		taps.append({"time_sec": snappedf(tap_times[index], 0.0001), "lane": tap_lanes[index]})
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Recording: cannot write '%s' (%s)" % [path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "song": song_path, "taps": taps}, "\t") + "\n")
	return OK


func add_tap(time_sec: float, lane: int) -> void:
	var index: int = tap_times.bsearch(time_sec)
	tap_times.insert(index, time_sec)
	tap_lanes.insert(index, lane)


## Removes the tap closest before `time_sec` (undo while recording).
func remove_last_before(time_sec: float) -> bool:
	var index: int = tap_times.bsearch(time_sec) - 1
	if index < 0:
		return false
	tap_times.remove_at(index)
	tap_lanes.remove_at(index)
	return true


## Clears every tap at or after `time_sec` (re-record from here).
func clear_from(time_sec: float) -> int:
	var index: int = tap_times.bsearch(time_sec)
	var removed: int = tap_times.size() - index
	tap_times.resize(index)
	tap_lanes.resize(index)
	return removed


func count() -> int:
	return tap_times.size()
