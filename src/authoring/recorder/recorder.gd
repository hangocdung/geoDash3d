# Record mode (dev tool): play the song (25–100% speed, original pitch) and tap along; taps are saved raw
# (time + lane) to assets/music/<id>.recording.json, then tools/charting/recording_level.py builds a level.
# Lanes: Space/J = auto obstacle, K = wall, L = gate. Paused: pick, nudge and delete single taps; A–B loop.
# Related: recording.gd, recording_editor.gd, recorder_timeline.gd, pitch_keeper.gd, docs/chart_format.md
class_name Recorder
extends Control

const SEEK_BARS_BEATS: float = 8.0
const GRIDS: Array[float] = [1.0, 0.5, 0.25]
const RATES: Array[float] = [0.25, 0.5, 0.75, 1.0]
const LANE_KEYS: Dictionary[Key, int] = {KEY_SPACE: 0, KEY_J: 0, KEY_K: 1, KEY_L: 2}
const PICK_RADIUS_PX: float = 24.0
const START_COUNT_IN_SEC: float = 1.0
const HELP_TEXT: String = "[Space/J] tap   [K] wall   [L] gate   [Backspace] undo   [X] clear from here   [G] grid   " \
		+ "[-/=] speed   [P] pause\n" \
		+ "[←/→] 2 bars   [,/.] 1 beat   [Home] restart   [A/B] loop start/end   [C] no loop   [R] clear loop taps   " \
		+ "[S] save   [Esc] save & exit\n" \
		+ "Paused: click = seek + select, right-click = delete   [Tab/Shift+Tab] select   [Shift+←/→] move by grid   " \
		+ "[J/K/L] set lane   [Del] delete"

## Chart picked in the menu (consumed on load); --record-chart=res://… on the command line wins.
static var next_chart_path: String = ""

var _chart_path: String = Scenes.DEFAULT_CHART
var _chart: LevelChart
var _song: AudioStream
var _recording: Recording
var _editor: RecordingEditor
var _clock: SongClock
var _pitch: PitchKeeper = PitchKeeper.new()
var _timeline: RecorderTimeline
var _status: Label
var _grid_index: int = 1
var _rate_index: int = RATES.size() - 1
var _dirty: bool = false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not next_chart_path.is_empty():
		_chart_path = next_chart_path
		next_chart_path = ""
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
	_editor = RecordingEditor.new(_recording, _chart.tempo)
	_timeline.tempo = _chart.tempo
	_timeline.editor = _editor
	_build_clock()
	_seek_to(0.0)


func _exit_tree() -> void:
	_pitch.release()


func _process(_delta: float) -> void:
	if _clock == null:
		return
	if _editor.has_loop() and _clock.state == SongClock.State.PLAYING and _clock.frame_time() >= _editor.loop_end_sec:
		_seek_to(_editor.loop_start_sec)
	var time_sec: float = _clock.frame_time()
	var beat: float = _chart.beat_at_time(time_sec)
	_timeline.now_sec = time_sec
	_timeline.grid_beats = GRIDS[_grid_index]
	_timeline.zoom = RATES[_rate_index]
	var selection: String = ""
	if _editor.selected >= 0:
		selection = "   selected #%d beat %.2f %s" % [_editor.selected + 1, _chart.beat_at_time(_editor.selected_time()),
				RecorderTimeline.LANE_NAMES[clampi(_recording.tap_lanes[_editor.selected], 0, 2)]]
	_status.text = "%s   %.2f s   bar %d beat %d   taps %d   grid 1/%d   speed %d%%%s%s   %s%s" % [
		_chart.title, time_sec, floori(beat / 4.0) + 1, posmod(floori(beat), 4) + 1, _recording.count(),
		roundi(1.0 / GRIDS[_grid_index]), roundi(RATES[_rate_index] * 100.0),
		"   LOOP" if _editor.has_loop() else "", selection,
		"PAUSED   " if _paused() else "", "unsaved" if _dirty else "saved"]


## _input (not _unhandled_input): full-screen controls would otherwise swallow mouse taps.
func _input(event: InputEvent) -> void:
	if _clock == null:
		return
	if event is InputEventMouseButton and event.is_pressed():
		_on_mouse(event as InputEventMouseButton)
		return
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	var key_event: InputEventKey = event as InputEventKey
	var key: Key = key_event.physical_keycode
	if LANE_KEYS.has(key):
		if _paused():
			_mark_dirty(_editor.set_selected_lane(LANE_KEYS[key]))
		else:
			_record_tap(LANE_KEYS[key])
		return
	if key_event.shift_pressed and (key == KEY_LEFT or key == KEY_RIGHT):
		_mark_dirty(_editor.nudge_selected(-1 if key == KEY_LEFT else 1, GRIDS[_grid_index]))
		return
	match key:
		KEY_BACKSPACE:
			_editor.deselect()
			_mark_dirty(_recording.remove_last_before(_clock.now()))
		KEY_DELETE:
			_mark_dirty(_editor.delete_selected())
		KEY_X:
			_editor.deselect()
			_mark_dirty(_recording.clear_from(_clock.frame_time()) > 0)
		KEY_TAB:
			_editor.select_step(_clock.frame_time(), -1 if key_event.shift_pressed else 1)
			if _paused() and _editor.selected >= 0:
				_seek_to(_editor.selected_time())
		KEY_G:
			_grid_index = (_grid_index + 1) % GRIDS.size()
		KEY_MINUS:
			_set_rate(maxi(_rate_index - 1, 0))
		KEY_EQUAL:
			_set_rate(mini(_rate_index + 1, RATES.size() - 1))
		KEY_P:
			if _paused():
				_clock.resume(0.0)
			else:
				_clock.pause()
		KEY_LEFT, KEY_RIGHT:
			_seek_by_beats(SEEK_BARS_BEATS * (-1.0 if key == KEY_LEFT else 1.0))
		KEY_COMMA, KEY_PERIOD:
			_seek_by_beats(-1.0 if key == KEY_COMMA else 1.0)
		KEY_HOME:
			_seek_to(0.0)
		KEY_A:
			_editor.set_loop_start(_clock.frame_time())
		KEY_B:
			_editor.set_loop_end(_clock.frame_time())
		KEY_C:
			_editor.clear_loop()
		KEY_R:
			_mark_dirty(_editor.clear_loop_taps() > 0)
		KEY_S:
			_save()
		KEY_ESCAPE:
			_save()
			Scenes.go_to(get_tree(), Scenes.MAIN_MENU)


func _on_mouse(event: InputEventMouseButton) -> void:
	var on_timeline: bool = _timeline.get_global_rect().has_point(event.global_position)
	var time_sec: float = _timeline.time_at_x(event.global_position.x - _timeline.global_position.x)
	var radius: float = _timeline.seconds_per_pixels(PICK_RADIUS_PX)
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if not _paused():
				_record_tap(0)
			elif on_timeline:
				_editor.select_near(time_sec, radius)
				_seek_to(time_sec)
		MOUSE_BUTTON_RIGHT:
			if on_timeline and _editor.select_near(time_sec, radius):
				_mark_dirty(_editor.delete_selected())
				_editor.deselect()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if on_timeline and _paused():
				_seek_by_beats(GRIDS[_grid_index] * (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0))


func _record_tap(lane: int) -> void:
	if _clock.state != SongClock.State.PLAYING:
		return
	_editor.deselect()
	_recording.add_tap(_clock.now(), lane)
	_dirty = true


func _mark_dirty(changed: bool) -> void:
	_dirty = _dirty or changed


func _paused() -> bool:
	return _clock.state == SongClock.State.PAUSED


func _save() -> void:
	if not _dirty:
		return
	if _recording.save_file(Recording.path_for_chart(_chart_path)) == OK:
		_dirty = false


func _set_rate(index: int) -> void:
	_rate_index = index
	_clock.playback_rate = RATES[_rate_index]
	_pitch.apply(RATES[_rate_index])
	_clock.calibration_offset_sec = UserSettings.audio_offset_sec + _pitch.latency_sec()
	_seek_to(_clock.frame_time())


func _seek_by_beats(beats: float) -> void:
	var beat: float = _chart.beat_at_time(_clock.frame_time()) + beats
	_seek_to(_chart.time_at(beat))


## Restarts the audio at `time_sec`; stays paused if it was paused.
func _seek_to(time_sec: float) -> void:
	var paused: bool = _paused()
	var target: float = clampf(time_sec, 0.0, _song.get_length() - 0.5)
	_clock.start(_song, target, START_COUNT_IN_SEC if target <= 0.0 else 0.0)
	if paused:
		_clock.pause()


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
	_status = UiTheme.make_label("", 26)
	column.add_child(_status)
	_timeline = RecorderTimeline.new()
	_timeline.custom_minimum_size = Vector2(0, 360)
	_timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_timeline)
	column.add_child(UiTheme.make_label(HELP_TEXT, 22, Color(0.7, 0.75, 0.9)))
