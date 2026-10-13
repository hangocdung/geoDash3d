# The single source of song time (seconds into the audio file, as heard by the player).
# AUDIO_SYNC follows the audio hardware clock with smoothing; FRAME_DELTA / MANUAL drive time
# deterministically for capture, movie recording and tests. Related: src/core/tempo_map.gd
class_name SongClock
extends Node

signal state_changed(new_state: State)
signal song_finished

enum State { STOPPED, COUNT_IN, PLAYING, PAUSED, FINISHED }
enum DriveMode { AUDIO_SYNC, FRAME_DELTA, MANUAL }

## Larger drift than this snaps to the audio clock instead of easing toward it.
const SNAP_THRESHOLD_SEC: float = 0.05
## Fraction of the remaining drift corrected each frame while easing.
const DRIFT_CORRECTION: float = 0.12
const MICROSECONDS: float = 1_000_000.0

@export var audio_player: AudioStreamPlayer
@export var drive_mode: DriveMode = DriveMode.AUDIO_SYNC

## Player calibration (seconds). Positive = the player hears audio later than the engine reports.
var calibration_offset_sec: float = 0.0
## Playback speed (practice tool). Also applied to the audio pitch.
var playback_rate: float = 1.0:
	set(value):
		playback_rate = clampf(value, 0.25, 2.0)
		if audio_player != null:
			audio_player.pitch_scale = playback_rate

var state: State = State.STOPPED
var _time_sec: float = 0.0
var _audio_start_sec: float = 0.0
var _last_update_usec: int = 0
var _cached_output_latency: float = 0.0


func _ready() -> void:
	if audio_player == null:
		push_error("SongClock: audio_player is not assigned")
		return
	audio_player.finished.connect(_on_audio_finished)
	_cached_output_latency = AudioServer.get_output_latency()


## Starts counting from `from_sec - count_in_sec`; audio begins exactly at `from_sec`.
func start(stream: AudioStream, from_sec: float, count_in_sec: float) -> void:
	if audio_player == null:
		push_error("SongClock: cannot start without audio_player")
		return
	audio_player.stop()
	audio_player.stream = stream
	_audio_start_sec = maxf(from_sec, 0.0)
	_time_sec = from_sec - maxf(count_in_sec, 0.0)
	_last_update_usec = Time.get_ticks_usec()
	_cached_output_latency = AudioServer.get_output_latency()
	if drive_mode == DriveMode.MANUAL:
		_set_state(State.PLAYING)
		return
	_set_state(State.COUNT_IN)
	_try_begin_audio()


func stop() -> void:
	if audio_player != null:
		audio_player.stop()
	_set_state(State.STOPPED)


func pause() -> void:
	if state != State.PLAYING and state != State.COUNT_IN:
		return
	if audio_player != null:
		audio_player.stream_paused = true
	_set_state(State.PAUSED)


## Resumes with a count-in: time rewinds by `count_in_sec` so the player sees the run up again.
func resume(count_in_sec: float) -> void:
	if state != State.PAUSED:
		return
	if audio_player != null:
		audio_player.stop()
		audio_player.stream_paused = false
	_audio_start_sec = maxf(_time_sec, 0.0)
	_time_sec -= maxf(count_in_sec, 0.0)
	_last_update_usec = Time.get_ticks_usec()
	_set_state(State.COUNT_IN)
	_try_begin_audio()


func set_manual_time(time_sec: float) -> void:
	_time_sec = time_sec
	_last_update_usec = Time.get_ticks_usec()


## Song time right now, extrapolated from the last frame update (use for input timestamps).
func now() -> float:
	if not _is_running() or drive_mode != DriveMode.AUDIO_SYNC:
		return _time_sec
	var elapsed: float = float(Time.get_ticks_usec() - _last_update_usec) / MICROSECONDS
	return _time_sec + elapsed * playback_rate


## Song time as of the current frame (use for simulation and visuals).
func frame_time() -> float:
	return _time_sec


func _process(delta: float) -> void:
	if not _is_running():
		return
	match drive_mode:
		DriveMode.MANUAL:
			return
		DriveMode.FRAME_DELTA:
			_time_sec += delta * playback_rate
			_last_update_usec = Time.get_ticks_usec()
		DriveMode.AUDIO_SYNC:
			_advance_audio_synced()
	if state == State.COUNT_IN:
		_try_begin_audio()


func _advance_audio_synced() -> void:
	var now_usec: int = Time.get_ticks_usec()
	var wall_time: float = _time_sec + float(now_usec - _last_update_usec) / MICROSECONDS * playback_rate
	_last_update_usec = now_usec
	if state != State.PLAYING or not audio_player.playing:
		_time_sec = wall_time
		return
	var heard_time: float = audio_player.get_playback_position() \
			+ AudioServer.get_time_since_last_mix() * playback_rate \
			- _cached_output_latency - calibration_offset_sec
	var drift: float = heard_time - wall_time
	var corrected: float = heard_time if absf(drift) > SNAP_THRESHOLD_SEC else wall_time + drift * DRIFT_CORRECTION
	# Never run backwards: gameplay simulation only advances forward.
	_time_sec = maxf(corrected, _time_sec)


func _try_begin_audio() -> void:
	if state != State.COUNT_IN:
		return
	# Audio must leave the engine early by the output latency (+ calibration) so that what the
	# player hears lines up with song time. Deterministic modes play audio only for monitoring.
	var lead_sec: float = 0.0
	if drive_mode == DriveMode.AUDIO_SYNC:
		lead_sec = _cached_output_latency + calibration_offset_sec
	if _time_sec + lead_sec < _audio_start_sec:
		return
	audio_player.play(maxf(_time_sec + lead_sec, 0.0))
	_set_state(State.PLAYING)


func _is_running() -> bool:
	return state == State.COUNT_IN or state == State.PLAYING or state == State.FINISHED


func _on_audio_finished() -> void:
	if state == State.PLAYING:
		_set_state(State.FINISHED)
		song_finished.emit()


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)
