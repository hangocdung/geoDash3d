# Record mode (dev tool): play the song and tap along; taps are saved raw (time + lane) to
# assets/music/<id>.recording.json for tools/audio/draft_chart.py to quantize into a chart.
# Lanes: Space/J/click = 0, K = 1, L = 2. See HELP_TEXT for the other keys.
# Related: recording.gd, recorder_timeline.gd, docs/chart_format.md
class_name Recorder
extends Control

const SEEK_BEATS: float = 8.0
const GRIDS: Array[float] = [1.0, 0.5, 0.25]
const RATES: Array[float] = [0.5, 0.75, 1.0]
const LANE_KEYS: Dictionary[Key, int] = {KEY_SPACE: 0, KEY_J: 0, KEY_K: 1, KEY_L: 2}
const HELP_TEXT: String = "[Space/J/K/L] tap lane 0/0/1/2   [Backspace] undo   [X] clear from here   [G] grid\n" \
		+ "[-/=] speed   [P] pause   [←/→] seek 2 bars   [Home] restart   [S] save   [Esc] save & exit"

var _chart_path: String = Scenes.DEFAULT_CHART
var _chart: LevelChart
var _song: AudioStream
var _recording: Recording
var _clock: SongClock
var _timeline: RecorderTimeline
var _status: Label
var _grid_index: int = 1
var _rate_index: int = 2
var _dirty: bool = false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--record-chart="):
			_chart_path = argument.trim_prefix("--record-chart=")
	_build_layout()
	_chart = ChartLoader.load_file(_chart_path, GameplayConfig.create_default())
	_song = load(_chart.song_path) as AudioStream if _chart != null else null
	if _song == null:
		_status.text = "Cannot load chart/song: %s" % _chart_path
		return
	_recording = Recording.load_file(Recording.path_for_chart(_chart_path))
	_recording.song_path = _chart.song_path
	_timeline.tempo = _chart.tempo
	_timeline.recording = _recording
	_build_clock()
	_seek_to(0.0)


func _process(_delta: float) -> void:
	if _clock == null:
		return
	var time_sec: float = _clock.frame_time()
	var beat: float = _chart.beat_at_time(time_sec)
	_timeline.now_sec = time_sec
	_timeline.grid_beats = GRIDS[_grid_index]
	_status.text = "%s   %.2f s   bar %d beat %d   taps %d   grid 1/%d   speed %d%%   %s%s" % [
		_chart.title, time_sec, floori(beat / 4.0) + 1, posmod(floori(beat), 4) + 1, _recording.count(),
		roundi(1.0 / GRIDS[_grid_index]), roundi(RATES[_rate_index] * 100.0),
		"PAUSED   " if _clock.state == SongClock.State.PAUSED else "", "unsaved" if _dirty else "saved"]


## _input (not _unhandled_input): full-screen controls would otherwise swallow mouse taps.
func _input(event: InputEvent) -> void:
	if _clock == null:
		return
	if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_record_tap(0)
		return
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	var key: Key = (event as InputEventKey).physical_keycode
	if LANE_KEYS.has(key):
		_record_tap(LANE_KEYS[key])
		return
	match key:
		KEY_BACKSPACE:
			_dirty = _recording.remove_last_before(_clock.now()) or _dirty
		KEY_X:
			_dirty = _recording.clear_from(_clock.frame_time()) > 0 or _dirty
		KEY_G:
			_grid_index = (_grid_index + 1) % GRIDS.size()
		KEY_MINUS:
			_set_rate(maxi(_rate_index - 1, 0))
		KEY_EQUAL:
			_set_rate(mini(_rate_index + 1, RATES.size() - 1))
		KEY_P:
			if _clock.state == SongClock.State.PAUSED:
				_clock.resume(0.0)
			else:
				_clock.pause()
		KEY_LEFT:
			_seek_by_beats(-SEEK_BEATS)
		KEY_RIGHT:
			_seek_by_beats(SEEK_BEATS)
		KEY_HOME:
			_seek_to(0.0)
		KEY_S:
			_save()
		KEY_ESCAPE:
			_save()
			Scenes.go_to(get_tree(), Scenes.MAIN_MENU)


func _record_tap(lane: int) -> void:
	if _clock.state != SongClock.State.PLAYING:
		return
	_recording.add_tap(_clock.now(), lane)
	_dirty = true


func _save() -> void:
	if not _dirty:
		return
	if _recording.save_file(Recording.path_for_chart(_chart_path)) == OK:
		_dirty = false


func _set_rate(index: int) -> void:
	_rate_index = index
	_clock.playback_rate = RATES[_rate_index]
	_seek_to(_clock.frame_time())


func _seek_by_beats(beats: float) -> void:
	var beat: float = _chart.beat_at_time(_clock.frame_time()) + beats
	_seek_to(_chart.time_at(beat))


func _seek_to(time_sec: float) -> void:
	var target: float = clampf(time_sec, 0.0, _song.get_length() - 0.5)
	_clock.start(_song, target, 1.0 if target <= 0.0 else 0.0)


func _build_clock() -> void:
	_clock = SongClock.new()
	_clock.name = "SongClock"
	var player := AudioStreamPlayer.new()
	player.name = "Music"
	player.bus = AudioBuses.MUSIC
	_clock.add_child(player)
	_clock.audio_player = player
	_clock.calibration_offset_sec = UserSettings.audio_offset_sec
	add_child(_clock)


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color(0.03, 0.01, 0.08)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 24)
	add_child(column)
	column.add_child(UiTheme.make_label("RECORD MODE", 52, UiTheme.ACCENT))
	_status = UiTheme.make_label("", 28)
	column.add_child(_status)
	_timeline = RecorderTimeline.new()
	_timeline.custom_minimum_size = Vector2(0, 360)
	_timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_timeline)
	column.add_child(UiTheme.make_label(HELP_TEXT, 24, Color(0.7, 0.75, 0.9)))
