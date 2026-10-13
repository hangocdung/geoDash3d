# Matches taps to action cues: the nearest unconsumed cue inside the timing window wins.
# Also reports cues whose window closed without a tap (misses).
# Related: src/gameplay/simulation/run_simulation.gd, src/gameplay/simulation/judgement.gd
class_name ActionResolver
extends RefCounted

const NO_CUE: int = -1

var _cues: Array[ChartItems.ActionCue]
var _tempo: TempoMap
var _window_sec: float
var _consumed: PackedByteArray = []
## Index of the first cue whose window has not closed yet.
var _open_index: int = 0


func _init(cues: Array[ChartItems.ActionCue], tempo: TempoMap, window_sec: float) -> void:
	_cues = cues
	_tempo = tempo
	_window_sec = window_sec
	_consumed.resize(cues.size())
	_consumed.fill(0)


## Marks every cue before `beat` as already handled (used when starting mid-chart).
func skip_before(beat: float) -> void:
	while _open_index < _cues.size() and _cues[_open_index].beat < beat:
		_consumed[_open_index] = 1
		_open_index += 1


## Returns the cue index matched by a tap at `tap_beat`, or NO_CUE.
func match_tap(tap_beat: float) -> int:
	var tap_time: float = _tempo.beat_to_time(tap_beat)
	var best_index: int = NO_CUE
	var best_error: float = INF
	for index: int in range(_open_index, _cues.size()):
		var error: float = tap_time - _tempo.beat_to_time(_cues[index].beat)
		if error < -_window_sec:
			break
		if _consumed[index] == 1 or absf(error) > _window_sec:
			continue
		if absf(error) < best_error:
			best_error = absf(error)
			best_index = index
	return best_index


func consume(index: int) -> void:
	_consumed[index] = 1


func timing_error_sec(index: int, tap_beat: float) -> float:
	return _tempo.beat_to_time(tap_beat) - _tempo.beat_to_time(_cues[index].beat)


## Closes windows that ended before `beat`; returns indices of cues that were never tapped.
func collect_missed(beat: float) -> PackedInt32Array:
	var missed: PackedInt32Array = []
	var now_time: float = _tempo.beat_to_time(beat)
	while _open_index < _cues.size():
		var cue_time: float = _tempo.beat_to_time(_cues[_open_index].beat)
		if now_time - cue_time <= _window_sec:
			break
		if _consumed[_open_index] == 0:
			_consumed[_open_index] = 1
			missed.append(_open_index)
		_open_index += 1
	return missed


func cue(index: int) -> ChartItems.ActionCue:
	return _cues[index]
