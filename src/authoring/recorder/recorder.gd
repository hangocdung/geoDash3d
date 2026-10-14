# Record mode (dev tool): the song is split into short segments; each is shown whole and can loop (with a
# pre-roll) at 25–100% speed, original pitch. Tap along (keys or on-screen pads) to place notes, then click,
# drag, add or delete them; BUILD & PLAY runs tools/charting/recording_level.py and play-tests the segment.
# Related: recorder_toolbar.gd, recorder_timeline.gd, recorder_playback.gd, recorder_segments.gd, recording_editor.gd
class_name Recorder
extends Control

const GRIDS: Array[float] = [1.0, 0.5, 0.25]
const RATES: Array[float] = [0.25, 0.5, 0.75, 1.0]
const PREROLL_BEATS: float = 4.0
const HELP_TEXT: String = "Playing: J/K/L or the pads add notes   Paused: pads add a note at the playhead   " \
		+ "Timeline: click = play from there, drag a note = move, double-click = add, right-click = delete   " \
		+ "Keys: P play  ←/→ beat  PgUp/PgDn segment  Ctrl+Z/Y undo/redo  Del delete  -/= speed  G grid  S save"

## Chart and segment to open (set by the menu or when coming back from a play-test; consumed on load).
static var next_chart_path: String = ""
static var next_segment: int = 0

var _chart_path: String = Scenes.DEFAULT_CHART
var _chart: LevelChart
var _song: AudioStream
var _recording: Recording
var _editor: RecordingEditor
var _segments: Array[RecorderSegments.Segment] = []
var _segment_index: int = 0
var _playback: RecorderPlayback
var _timeline: RecorderTimeline
var _toolbar: RecorderToolbar
var _segment_strip: RecorderSegmentStrip
var _status: Label
var _message: Label
var _grid_index: int = 1
var _rate_index: int = 1
var _loop: bool = true
var _preroll: bool = true
var _record: bool = true
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
	_chart = ChartLoader.load_file(_chart_path, GameplayConfig.create_default())
	_song = load(_chart.song_path) as AudioStream if _chart != null else null
	_build_layout()
	if _song == null:
		_status.text = "Cannot load chart/song: %s" % _chart_path
		return
	_recording = Recording.load_file(Recording.path_for_chart(_chart_path))
	_recording.song_path = _chart.song_path
	_editor = RecordingEditor.new(_recording, _chart.tempo)
	_segments = RecorderSegments.from_chart(_chart)
	_timeline.tempo = _chart.tempo
	_timeline.editor = _editor
	_segment_strip.setup(_segments)
	_refresh_segment_labels()
	_playback.setup(_song)
	_grid_index = maxi(GRIDS.find(_recording.grid_beats), 0)
	_toolbar.set_rate(_rate_index)
	_toolbar.set_grid(_grid_index)
	_toolbar.set_toggle(&"loop", _loop)
	_toolbar.set_toggle(&"preroll", _preroll)
	_toolbar.set_toggle(&"record", _record)
	_playback.set_rate(RATES[_rate_index])
	_select_segment(clampi(next_segment, 0, _segments.size() - 1), true)
	next_segment = 0


func _process(_delta: float) -> void:
	if _editor == null:
		return
	var time_sec: float = _playback.time()
	var segment: RecorderSegments.Segment = _segments[_segment_index]
	if _playback.is_playing() and time_sec >= _chart.time_at(segment.end_beat):
		if _loop:
			_playback.seek(_play_start())
		elif _segment_index + 1 < _segments.size():
			_select_segment(_segment_index + 1, false)
	_timeline.now_sec = _playback.time()
	_timeline.grid_beats = GRIDS[_grid_index]
	_toolbar.set_playing(_playback.is_playing())
	_toolbar.set_enabled(&"undo", _editor.can_undo())
	_toolbar.set_enabled(&"redo", _editor.can_redo())
	for name: StringName in [&"delete", &"lane_0", &"lane_1", &"lane_2"]:
		_toolbar.set_enabled(name, _editor.selected >= 0)
	_update_status(time_sec)


func _update_status(time_sec: float) -> void:
	var beat: float = _chart.beat_at_time(time_sec)
	var segment: RecorderSegments.Segment = _segments[_segment_index]
	var selection: String = ""
	if _editor.selected >= 0:
		selection = "   selected: bar %s %s" % [_bar_beat(_chart.beat_at_time(_editor.selected_time())),
				RecorderTimeline.LANE_NAMES[clampi(_recording.tap_lanes[_editor.selected], 0, 2)]]
	_status.text = "%s   ·   segment %d/%d %s   ·   bar %s   %.2f s   ·   %d notes here, %d total%s   ·   %s" % [
		_chart.title, _segment_index + 1, _segments.size(), segment.label, _bar_beat(beat), time_sec,
		_notes_in(segment), _recording.count(), selection, "unsaved" if _dirty else "saved"]


## _input (not _unhandled_input): the keyboard drives the recorder even while the mouse is over a button.
func _input(event: InputEvent) -> void:
	if _editor == null or not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	var action: StringName = RecorderKeys.action_for(event as InputEventKey)
	if not action.is_empty():
		_on_action(action)
		get_viewport().set_input_as_handled()


func _on_action(name: StringName) -> void:
	var segment: RecorderSegments.Segment = _segments[_segment_index]
	match name:
		&"play":
			_playback.toggle(_play_start())
		&"start":
			_playback.seek(_play_start())
		&"back_beat", &"forward_beat":
			var beat: float = _chart.beat_at_time(_playback.time()) + (-1.0 if name == &"back_beat" else 1.0)
			_playback.seek(_chart.time_at(beat))
			if beat < segment.start_beat - PREROLL_BEATS or beat >= segment.end_beat:
				_select_segment(RecorderSegments.index_at(_segments, beat), false)
		&"previous_segment", &"next_segment":
			_select_segment(clampi(_segment_index + (-1 if name == &"previous_segment" else 1), 0, _segments.size() - 1), true)
		&"loop":
			_loop = not _loop
		&"preroll":
			_preroll = not _preroll
		&"record":
			_record = not _record
		&"undo":
			_changed(_editor.undo())
		&"redo":
			_changed(_editor.redo())
		&"delete":
			_changed(_editor.delete_selected())
		&"pad_0", &"pad_1", &"pad_2":
			_on_pad(String(name).right(1).to_int())
		&"nudge_left", &"nudge_right":
			_changed(_editor.nudge_selected(-1 if name == &"nudge_left" else 1, GRIDS[_grid_index]))
		&"select_next", &"select_previous":
			_editor.select_step(_playback.time(), 1 if name == &"select_next" else -1)
		&"next_grid":
			_on_grid((_grid_index + 1) % GRIDS.size())
		&"slower", &"faster":
			_on_rate(clampi(_rate_index + (1 if name == &"faster" else -1), 0, RATES.size() - 1))
		&"lane_0", &"lane_1", &"lane_2":
			_changed(_editor.set_selected_lane(String(name).right(1).to_int()))
		&"align":
			var shift: float = _editor.align_range(_chart.time_at(segment.start_beat), _chart.time_at(segment.end_beat),
					GRIDS[_grid_index])
			_changed(not is_zero_approx(shift))
			_message.text = "Segment notes moved %+d ms onto the 1/%d grid (a steady delay? try CALIBRATE AUDIO)." % [
					roundi(shift * 1000.0), roundi(1.0 / GRIDS[_grid_index])]
		&"clear_segment":
			_changed(_editor.clear_range(_chart.time_at(segment.start_beat), _chart.time_at(segment.end_beat)) > 0)
		&"save":
			_save()
		&"build":
			_build_and_play()
		&"exit":
			_save()
			Scenes.go_to(get_tree(), Scenes.MAIN_MENU)


## A tap from a key or pad: recorded live while playing, added at the playhead (snapped) while paused.
func _on_pad(lane: int) -> void:
	if _playback.is_playing():
		if _record:
			_editor.record_tap(_playback.tap_time(), lane)
			_changed(true)
	elif _playback.is_paused():
		_editor.add_tap(_playback.time(), lane, GRIDS[_grid_index])
		_changed(true)


func _on_rate(index: int) -> void:
	_rate_index = index
	_playback.set_rate(RATES[index])
	_toolbar.set_rate(index)


func _on_grid(index: int) -> void:
	_grid_index = index
	_recording.grid_beats = GRIDS[index]
	_dirty = true
	_toolbar.set_grid(index)


func _changed(changed: bool) -> void:
	if not changed:
		return
	_dirty = true
	_refresh_segment_labels()


## Where Play / loop starts: the segment start, a bar earlier with pre-roll.
func _play_start() -> float:
	var beat: float = _segments[_segment_index].start_beat - (PREROLL_BEATS if _preroll else 0.0)
	return _chart.time_at(maxf(beat, 0.0))


func _select_segment(index: int, seek: bool) -> void:
	_segment_index = index
	var segment: RecorderSegments.Segment = _segments[index]
	_timeline.segment_start_beat = segment.start_beat
	_timeline.segment_end_beat = segment.end_beat
	_segment_strip.set_current(index)
	if seek:
		_editor.deselect()
		_playback.seek(_play_start())


func _save() -> void:
	if _dirty and _recording.save_file(Recording.path_for_chart(_chart_path)) == OK:
		_dirty = false


func _build_and_play() -> void:
	_save()
	if _recording.count() == 0:
		_message.text = "Record some notes first."
		return
	_playback.pause()
	var result: RecordingLevelBuild = RecordingLevelBuild.run(_chart_path)
	_message.text = result.message
	if not result.ok:
		return
	next_chart_path = _chart_path
	next_segment = _segment_index
	LaunchOptions.set_next_run(LaunchOptions.recorder_test_run(result.chart_path, _segments[_segment_index].start_beat))
	Scenes.go_to(get_tree(), Scenes.LEVEL)


func _notes_in(segment: RecorderSegments.Segment) -> int:
	return _recording.tap_times.bsearch(_chart.time_at(segment.end_beat)) \
			- _recording.tap_times.bsearch(_chart.time_at(segment.start_beat))


func _bar_beat(beat: float) -> String:
	return "%d.%d" % [floori(beat / 4.0) + 1, posmod(floori(beat), 4) + 1]


func _refresh_segment_labels() -> void:
	var counts: PackedInt32Array = []
	for segment: RecorderSegments.Segment in _segments:
		counts.append(_notes_in(segment))
	_segment_strip.set_counts(counts)


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color(0.03, 0.01, 0.08)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_playback = RecorderPlayback.new()
	_playback.name = "Playback"
	add_child(_playback)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_status = UiTheme.make_label("", 20)
	column.add_child(_status)
	_segment_strip = RecorderSegmentStrip.new()
	_segment_strip.chosen.connect(func(index: int) -> void: _select_segment(index, true))
	column.add_child(_segment_strip)
	_timeline = RecorderTimeline.new()
	_timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline.seek_requested.connect(func(time_sec: float) -> void: _playback.seek(time_sec))
	_timeline.add_requested.connect(func(time_sec: float, lane: int) -> void:
		_editor.add_tap(time_sec, lane, GRIDS[_grid_index])
		_changed(true))
	_timeline.move_requested.connect(func(time_sec: float, lane: int) -> void:
		_changed(_editor.move_selected(time_sec, lane, GRIDS[_grid_index])))
	_timeline.delete_requested.connect(func() -> void: _changed(_editor.delete_selected()))
	column.add_child(_timeline)
	_message = UiTheme.make_label("", 18, UiTheme.HOT)
	column.add_child(_message)
	_toolbar = RecorderToolbar.new()
	_toolbar.setup(RATES, GRIDS)
	_toolbar.action.connect(_on_action)
	_toolbar.rate_chosen.connect(_on_rate)
	_toolbar.grid_chosen.connect(_on_grid)
	_toolbar.pad_down.connect(_on_pad)
	column.add_child(_toolbar)
	var help: Label = UiTheme.make_label(HELP_TEXT, 14, Color(0.6, 0.65, 0.85))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)

