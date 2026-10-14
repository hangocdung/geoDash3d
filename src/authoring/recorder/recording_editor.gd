# Note editing for the recorder: one selected tap (delete, nudge by the grid, change its lane) and an
# A–B loop region that can be re-recorded. Pure data on top of Recording; the recorder maps keys/mouse to it.
# Related: src/authoring/recorder/recording.gd, src/authoring/recorder/recorder.gd
class_name RecordingEditor
extends RefCounted

var recording: Recording
var tempo: TempoMap
## Index into the recording, -1 = nothing selected.
var selected: int = -1
var loop_start_sec: float = 0.0
var loop_end_sec: float = 0.0
var _has_loop_start: bool = false
var _has_loop_end: bool = false


func _init(source: Recording, tempo_map: TempoMap) -> void:
	recording = source
	tempo = tempo_map


func deselect() -> void:
	selected = -1


## Selects the tap closest to `time_sec` within `radius_sec`; returns whether one was found.
func select_near(time_sec: float, radius_sec: float) -> bool:
	selected = recording.nearest(time_sec, radius_sec)
	return selected >= 0


## Selects the next (+1) or previous (-1) tap, starting from `time_sec` when nothing is selected.
func select_step(time_sec: float, direction: int) -> void:
	if recording.count() == 0:
		selected = -1
		return
	if selected < 0:
		var index: int = recording.tap_times.bsearch(time_sec)
		selected = index if direction > 0 else index - 1
	else:
		selected += direction
	selected = clampi(selected, 0, recording.count() - 1)


func selected_time() -> float:
	return recording.tap_times[selected] if selected >= 0 else 0.0


func delete_selected() -> bool:
	if selected < 0:
		return false
	recording.remove_at(selected)
	selected = mini(selected, recording.count() - 1)
	return true


## Snaps the selected tap to the grid, then moves it `direction` grid steps (0 = snap only).
func nudge_selected(direction: int, grid_beats: float) -> bool:
	if selected < 0:
		return false
	var beat: float = roundf(tempo.time_to_beat(recording.tap_times[selected]) / grid_beats) * grid_beats
	selected = recording.move_tap(selected, tempo.beat_to_time(beat + direction * grid_beats))
	return true


func set_selected_lane(lane: int) -> bool:
	if selected < 0:
		return false
	recording.set_lane(selected, lane)
	return true


func set_loop_start(time_sec: float) -> void:
	loop_start_sec = time_sec
	_has_loop_start = true
	if _has_loop_end and loop_end_sec <= loop_start_sec:
		_has_loop_end = false


func set_loop_end(time_sec: float) -> void:
	if _has_loop_start and time_sec <= loop_start_sec:
		push_error("RecordingEditor: loop end %.2f s must come after the start %.2f s" % [time_sec, loop_start_sec])
		return
	loop_end_sec = time_sec
	_has_loop_end = true


func clear_loop() -> void:
	_has_loop_start = false
	_has_loop_end = false


func has_loop() -> bool:
	return _has_loop_start and _has_loop_end


func has_loop_start() -> bool:
	return _has_loop_start


## Removes the taps inside the loop so the next pass records it again.
func clear_loop_taps() -> int:
	if not has_loop():
		return 0
	selected = -1
	return recording.clear_range(loop_start_sec, loop_end_sec)
