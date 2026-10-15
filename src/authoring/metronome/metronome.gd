# Sync test tool: plays a chart's song with a sample-locked click track (AudioStreamSynchronized)
# and flashes on every beat, so timing can be checked by ear and eye. Live calibration nudging.
# Keys: M music, C clicks, ←/→ calibration ±5 ms, S save, R restart, Esc menu; the same actions as touch buttons.
# Related: src/core/audio/click_track.gd, src/core/song_clock.gd
class_name Metronome
extends Control

const CALIBRATION_STEP_SEC: float = 0.005
const MUTED_DB: float = -80.0
const CLICK_DB: float = -3.0
const FLASH_DECAY_PER_SEC: float = 6.0

var _chart: LevelChart
var _stream: AudioStreamSynchronized
var _clock: SongClock
var _flash_panel: ColorRect
var _beat_label: Label
var _info_label: Label
var _music_on: bool = true
var _clicks_on: bool = true
var _last_beat: int = -1000
var _flash: float = 0.0


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layout()
	_chart = ChartLoader.load_file(Scenes.DEFAULT_CHART, GameplayConfig.create_default())
	var song: AudioStream = load(_chart.song_path) as AudioStream if _chart != null else null
	if song == null:
		_info_label.text = "Cannot load chart or song: %s" % Scenes.DEFAULT_CHART
		return
	_stream = AudioStreamSynchronized.new()
	_stream.stream_count = 2
	_stream.set_sync_stream(0, song)
	_stream.set_sync_stream(1, ClickTrack.generate(_chart.tempo, song.get_length()))
	_build_clock()
	_restart()


func _process(delta: float) -> void:
	if _clock == null:
		return
	var time_sec: float = _clock.frame_time()
	var beat: float = _chart.beat_at_time(time_sec)
	var whole_beat: int = int(floorf(beat))
	if whole_beat != _last_beat and beat >= 0.0:
		_last_beat = whole_beat
		_flash = 1.0 if posmod(whole_beat, 4) == 0 else 0.6
	_flash = maxf(_flash - delta * FLASH_DECAY_PER_SEC, 0.0)
	_flash_panel.color = Color(0.3, 0.9, 1.0).lerp(Color(1.0, 0.3, 0.85), 1.0 if posmod(whole_beat, 4) == 0 else 0.0) \
			* Color(1, 1, 1, _flash)
	_beat_label.text = "%d . %d" % [floori(beat / 4.0) + 1, posmod(whole_beat, 4) + 1]
	_info_label.text = ("t %.2f s   beat %.2f   drift %+.1f ms   latency %.1f ms\n" +
			"calibration %+d ms   music %s   clicks %s\n" +
			"[M] music  [C] clicks  [←/→] calibration ±5 ms  [S] save  [R] restart  [Esc] menu") % [
				time_sec, beat, _clock.audio_drift() * 1000.0, AudioServer.get_output_latency() * 1000.0,
				roundi(_clock.calibration_offset_sec * 1000.0), _on_off(_music_on), _on_off(_clicks_on)]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return
	var keys: Dictionary[Key, StringName] = {KEY_M: &"music", KEY_C: &"clicks", KEY_LEFT: &"earlier",
			KEY_RIGHT: &"later", KEY_S: &"save", KEY_R: &"restart", KEY_ESCAPE: &"menu"}
	var key: Key = (event as InputEventKey).physical_keycode
	if keys.has(key):
		_do(keys[key])


func _do(action: StringName) -> void:
	if _clock == null and action != &"menu":
		return
	match action:
		&"music":
			_music_on = not _music_on
			_apply_volumes()
		&"clicks":
			_clicks_on = not _clicks_on
			_apply_volumes()
		&"earlier":
			_nudge_calibration(-CALIBRATION_STEP_SEC)
		&"later":
			_nudge_calibration(CALIBRATION_STEP_SEC)
		&"save":
			UserSettings.audio_offset_sec = _clock.calibration_offset_sec
			UserSettings.save_settings()
		&"restart":
			_restart()
		&"menu":
			Scenes.go_to(get_tree(), Scenes.MAIN_MENU)


func _restart() -> void:
	_last_beat = -1000
	_apply_volumes()
	_clock.start(_stream, 0.0, 1.0)


## Calibration changes the audio lead, so restart from the current position to re-sync cleanly.
func _nudge_calibration(step_sec: float) -> void:
	var position_sec: float = maxf(_clock.frame_time(), 0.0)
	_clock.calibration_offset_sec = clampf(_clock.calibration_offset_sec + step_sec,
			-UserSettings.MAX_CALIBRATION_SEC, UserSettings.MAX_CALIBRATION_SEC)
	_clock.start(_stream, position_sec, 0.0)


func _apply_volumes() -> void:
	_stream.set_sync_stream_volume(0, 0.0 if _music_on else MUTED_DB)
	_stream.set_sync_stream_volume(1, CLICK_DB if _clicks_on else MUTED_DB)


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
	_flash_panel = ColorRect.new()
	_flash_panel.set_anchors_preset(Control.PRESET_CENTER)
	_flash_panel.custom_minimum_size = Vector2(360, 360)
	_flash_panel.position = Vector2(-180, -260)
	add_child(_flash_panel)
	_beat_label = UiTheme.make_label("", 72)
	_beat_label.set_anchors_preset(Control.PRESET_CENTER)
	_beat_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_beat_label.position.y = -130
	add_child(_beat_label)
	_info_label = UiTheme.make_label("", 26)
	_info_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_info_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_info_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_label.position.y -= 150
	_info_label.add_theme_color_override("font_color", UiTheme.MUTED)
	add_child(_info_label)
	var margins: Vector4 = UiKit.safe_margins(self)
	var header: HBoxContainer = UiKit.header("SYNC TEST", "CHECK THE BEAT BY EAR AND EYE", &"wave", _do.bind(&"menu"))
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = margins.x
	header.offset_top = margins.y
	header.offset_right = -margins.z
	add_child(header)
	var toolbar := HFlowContainer.new()
	toolbar.alignment = FlowContainer.ALIGNMENT_CENTER
	toolbar.add_theme_constant_override("h_separation", 14)
	toolbar.add_theme_constant_override("v_separation", 14)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toolbar.offset_left = margins.x
	toolbar.offset_right = -margins.z
	toolbar.offset_top = -margins.w - 64.0
	toolbar.offset_bottom = -margins.w
	toolbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(toolbar)
	for spec: Array in [["MUSIC", &"music", &"music"], ["CLICKS", &"wave", &"clicks"], ["−5 ms", &"back", &"earlier"],
			["+5 ms", &"chevron", &"later"], ["SAVE", &"check", &"save"], ["RESTART", &"restart", &"restart"]]:
		var button: Button = UiKit.button(spec[0], spec[1], "SmallButton", false, Vector2(0, 60))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_do.bind(spec[2]))
		toolbar.add_child(button)


static func _on_off(value: bool) -> String:
	return "on" if value else "off"
