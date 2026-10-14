# Note editing for the recorder: one selected tap (add, move, delete), clearing a range, aligning timing, and
# undo/redo of every change (snapshots of the tap arrays). Pure data on top of Recording.
# Related: src/authoring/recorder/recording.gd, src/authoring/recorder/recorder.gd
class_name RecordingEditor
extends RefCounted

const MAX_UNDO: int = 200

var recording: Recording
var tempo: TempoMap
## Index into the recording, -1 = nothing selected.
var selected: int = -1
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


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


## Live tap while the song plays (one undo step per tap).
func record_tap(time_sec: float) -> void:
	_checkpoint()
	selected = -1
	recording.add_tap(time_sec, 0)


## Adds a tap snapped to the grid and selects it.
func add_tap(time_sec: float, grid_beats: float) -> void:
	_checkpoint()
	var time_snapped: float = snap_time(time_sec, grid_beats)
	recording.add_tap(time_snapped, 0)
	selected = recording.tap_times.bsearch(time_snapped)


func delete_selected() -> bool:
	if selected < 0:
		return false
	_checkpoint()
	recording.remove_at(selected)
	selected = mini(selected, recording.count() - 1)
	return true


## Moves the selected tap to `time_sec` (snapped to the grid).
func move_selected(time_sec: float, grid_beats: float) -> bool:
	if selected < 0:
		return false
	_checkpoint()
	selected = recording.move_tap(selected, snap_time(time_sec, grid_beats))
	return true


## Snaps the selected tap to the grid, then moves it `direction` grid steps (0 = snap only).
func nudge_selected(direction: int, grid_beats: float) -> bool:
	if selected < 0:
		return false
	var time_sec: float = tempo.beat_to_time(tempo.time_to_beat(snap_time(selected_time(), grid_beats))
			+ direction * grid_beats)
	return move_selected(time_sec, grid_beats)


## Removes every tap in [from_sec, to_sec) (re-record a segment).
func clear_range(from_sec: float, to_sec: float) -> int:
	var first: int = recording.tap_times.bsearch(from_sec)
	if first >= recording.count() or recording.tap_times[first] >= to_sec:
		return 0
	_checkpoint()
	selected = -1
	return recording.clear_range(from_sec, to_sec)


## Shifts the taps in [from_sec, to_sec) so their average distance to the grid is zero (removes a steady
## early/late tapping delay). Returns the shift in seconds (0 when there is nothing to align).
func align_range(from_sec: float, to_sec: float, grid_beats: float) -> float:
	var first: int = recording.tap_times.bsearch(from_sec)
	var last: int = recording.tap_times.bsearch(to_sec)
	if last <= first:
		return 0.0
	# Circular mean of each tap's phase within a grid step, so taps on both sides of a line average out.
	var phase_sum := Vector2.ZERO
	for index: int in range(first, last):
		var phase: float = tempo.time_to_beat(recording.tap_times[index]) / grid_beats * TAU
		phase_sum += Vector2(cos(phase), sin(phase))
	var shift_beats: float = -phase_sum.angle() / TAU * grid_beats
	if is_zero_approx(shift_beats):
		return 0.0
	_checkpoint()
	var middle: float = recording.tap_times[(first + last) / 2]
	var shift_sec: float = tempo.beat_to_time(tempo.time_to_beat(middle) + shift_beats) - middle
	for index: int in range(first, last):
		recording.tap_times[index] = tempo.beat_to_time(tempo.time_to_beat(recording.tap_times[index]) + shift_beats)
	return shift_sec


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(_snapshot())
	_restore(_redo.pop_back())
	return true


func snap_time(time_sec: float, grid_beats: float) -> float:
	return tempo.beat_to_time(roundf(tempo.time_to_beat(time_sec) / grid_beats) * grid_beats)


func _checkpoint() -> void:
	_undo.append(_snapshot())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()


func _snapshot() -> Dictionary:
	return {"times": recording.tap_times.duplicate(), "lanes": recording.tap_lanes.duplicate(), "selected": selected}


func _restore(state: Dictionary) -> void:
	recording.tap_times = state["times"]
	recording.tap_lanes = state["lanes"]
	selected = mini(int(state["selected"]), recording.count() - 1)
