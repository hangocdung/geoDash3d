# Raw tap recording for charting: taps stored as song time + lane, quantized only when building
# the level (tools/charting/recording_level.py), so a recording survives tempo/offset fixes.
# File: assets/music/<id>.recording.json. Related: recorder.gd, tools/charting/sm_to_recording.py
class_name Recording
extends RefCounted

const VERSION: int = 1
## Level built from a recording (tools/charting/recording_level.py); it shares the source chart's recording.
const BUILT_CHART_SUFFIX: String = ".rec"

## Sorted by time.
var tap_times: PackedFloat64Array = []
var tap_lanes: PackedInt32Array = []
var song_path: String = ""


static func path_for_chart(chart_path: String) -> String:
	return chart_path.trim_suffix(".chart.json").trim_suffix(BUILT_CHART_SUFFIX) + ".recording.json"


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


## Removes every tap in [from_sec, to_sec) (re-record a loop).
func clear_range(from_sec: float, to_sec: float) -> int:
	var first: int = tap_times.bsearch(from_sec)
	var last: int = tap_times.bsearch(to_sec)
	for index: int in range(last - 1, first - 1, -1):
		remove_at(index)
	return last - first


func remove_at(index: int) -> void:
	if index < 0 or index >= tap_times.size():
		push_error("Recording: tap index %d out of range (%d taps)" % [index, tap_times.size()])
		return
	tap_times.remove_at(index)
	tap_lanes.remove_at(index)


## Moves a tap to `time_sec`, keeping the list sorted; returns its new index (-1 if `index` is invalid).
func move_tap(index: int, time_sec: float) -> int:
	if index < 0 or index >= tap_times.size():
		push_error("Recording: tap index %d out of range (%d taps)" % [index, tap_times.size()])
		return -1
	var lane: int = tap_lanes[index]
	remove_at(index)
	add_tap(time_sec, lane)
	return tap_times.bsearch(time_sec)


func set_lane(index: int, lane: int) -> void:
	if index < 0 or index >= tap_lanes.size():
		push_error("Recording: tap index %d out of range (%d taps)" % [index, tap_lanes.size()])
		return
	tap_lanes[index] = lane


## Index of the tap closest to `time_sec` within `max_distance_sec`, or -1.
func nearest(time_sec: float, max_distance_sec: float) -> int:
	var index: int = tap_times.bsearch(time_sec)
	var best: int = -1
	var best_distance: float = max_distance_sec
	for candidate: int in [index - 1, index]:
		if candidate < 0 or candidate >= tap_times.size():
			continue
		var distance: float = absf(tap_times[candidate] - time_sec)
		if distance <= best_distance:
			best = candidate
			best_distance = distance
	return best


func count() -> int:
	return tap_times.size()
