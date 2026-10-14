# Song playback for the recorder: a SongClock on the Music bus with seek (keeping play/pause), play/pause
# toggling and slow speeds at the original pitch (PitchKeeper; its delay is added to the calibration).
# Related: src/authoring/recorder/recorder.gd, src/authoring/recorder/pitch_keeper.gd, src/core/song_clock.gd
class_name RecorderPlayback
extends Node

var clock: SongClock
var _song: AudioStream
var _pitch: PitchKeeper = PitchKeeper.new()


func setup(song: AudioStream) -> void:
	_song = song
	clock = SongClock.new()
	clock.name = "SongClock"
	var player := AudioStreamPlayer.new()
	player.name = "Music"
	player.bus = AudioBuses.MUSIC
	clock.add_child(player)
	clock.audio_player = player
	clock.calibration_offset_sec = UserSettings.audio_offset_sec
	add_child(clock)


func _exit_tree() -> void:
	_pitch.release()


func is_playing() -> bool:
	return clock.state == SongClock.State.PLAYING or clock.state == SongClock.State.COUNT_IN


func is_paused() -> bool:
	return clock.state == SongClock.State.PAUSED


## Song time of this frame (display, loop checks).
func time() -> float:
	return clock.frame_time()


## Song time right now (timestamps for live taps).
func tap_time() -> float:
	return clock.now()


## Restarts the audio at `time_sec`; keeps the play/pause state unless `keep_state` is false (then plays).
func seek(time_sec: float, keep_state: bool = true) -> void:
	var paused: bool = keep_state and not is_playing()
	clock.start(_song, clampf(time_sec, 0.0, _song.get_length() - 0.5), 0.0)
	if paused:
		clock.pause()


## Pauses, resumes, or (when stopped/finished) plays from `from_sec`.
func toggle(from_sec: float) -> void:
	if is_playing():
		clock.pause()
	elif is_paused():
		clock.resume(0.0)
	else:
		seek(from_sec, false)


func pause() -> void:
	clock.pause()


func set_rate(rate: float) -> void:
	clock.playback_rate = rate
	_pitch.apply(rate)
	clock.calibration_offset_sec = UserSettings.audio_offset_sec + _pitch.latency_sec()
	if clock.state != SongClock.State.STOPPED:
		seek(clock.frame_time())
