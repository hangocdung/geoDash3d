# Audio latency calibration: plays clicks at 100 BPM, the player taps along to the sound for
# 16 beats after a 4-beat count-in, and the robust mean tap error becomes UserSettings.audio_offset_sec.
# Related: src/core/calibration_math.gd, src/core/audio/click_track.gd, src/core/user_settings.gd
class_name CalibrationScreen
extends Control

enum Phase { INTRO, RUNNING, RESULT }

const BPM: float = 100.0
const FIRST_CLICK_SEC: float = 0.6
const COUNT_IN_BEATS: int = 4
const MEASURED_BEATS: int = 16
const TAIL_BEATS: int = 2
const MAX_ACCEPTED_ERROR_SEC: float = 0.25
const MAX_GOOD_SPREAD_SEC: float = 0.04

var _phase: Phase = Phase.INTRO
var _tempo: TempoMap
var _clicks: AudioStreamWAV
var _clock: SongClock
var _errors: PackedFloat64Array = []
var _tapped_beats: Dictionary[int, bool] = {}
var _estimate: CalibrationMath.Estimate
var _indicator: Label
var _status: Label
var _start_button: Button
var _save_button: Button
var _retry_button: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tempo = TempoMap.constant(BPM, FIRST_CLICK_SEC)
	var duration: float = _tempo.beat_to_time(float(COUNT_IN_BEATS + MEASURED_BEATS + TAIL_BEATS))
	_clicks = ClickTrack.generate(_tempo, duration)
	_build_clock()
	_build_layout()
	_show_intro()


func _process(_delta: float) -> void:
	if _phase != Phase.RUNNING:
		return
	var beat: float = _tempo.time_to_beat(_clock.frame_time())
	if beat < 0.0:
		_indicator.text = "…"
	elif beat < COUNT_IN_BEATS:
		_indicator.text = str(COUNT_IN_BEATS - int(floorf(beat)))
	else:
		_indicator.text = "●".repeat(_errors.size()) + "○".repeat(maxi(MEASURED_BEATS - _errors.size(), 0))
	if beat >= COUNT_IN_BEATS + MEASURED_BEATS + 0.5:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.RUNNING or not event.is_action_pressed(&"tap", false, true):
		return
	get_viewport().set_input_as_handled()
	var tap_time: float = _clock.now()
	var beat: int = roundi(_tempo.time_to_beat(tap_time))
	if beat < COUNT_IN_BEATS or beat >= COUNT_IN_BEATS + MEASURED_BEATS or _tapped_beats.has(beat):
		return
	var error: float = CalibrationMath.tap_error(tap_time, _tempo)
	if absf(error) > MAX_ACCEPTED_ERROR_SEC:
		return
	_tapped_beats[beat] = true
	_errors.append(error)
	_status.text = "%+d ms" % roundi(error * 1000.0)


func _start() -> void:
	_phase = Phase.RUNNING
	_errors.clear()
	_tapped_beats.clear()
	_start_button.visible = false
	_save_button.visible = false
	_retry_button.visible = false
	_status.text = "Listen… tap on every click"
	_clock.start(_clicks, 0.0, 0.4)


func _finish() -> void:
	_phase = Phase.RESULT
	_clock.stop()
	_estimate = CalibrationMath.estimate(_errors)
	_retry_button.visible = true
	_retry_button.grab_focus()
	if not _estimate.is_valid:
		_indicator.text = "?"
		_status.text = "Not enough steady taps (%d). Try again." % _estimate.accepted_count
		return
	var offset_ms: int = roundi(_estimate.offset_sec * 1000.0)
	var spread_ms: int = roundi(_estimate.spread_sec * 1000.0)
	_indicator.text = "%+d ms" % offset_ms
	print("CALIBRATION offset_ms=%d spread_ms=%d taps=%d engine_latency_ms=%.1f" % [offset_ms, spread_ms,
			_estimate.accepted_count, AudioServer.get_output_latency() * 1000.0])
	var verdict: String = "Consistent" if _estimate.spread_sec <= MAX_GOOD_SPREAD_SEC else "Unsteady — consider retrying"
	_status.text = "Audio offset %+d ms  (±%d ms, %s)\nCurrent: %+d ms" % [offset_ms, spread_ms, verdict,
			roundi(UserSettings.audio_offset_sec * 1000.0)]
	_save_button.visible = true


func _save() -> void:
	if _estimate == null or not _estimate.is_valid:
		return
	UserSettings.audio_offset_sec = _estimate.offset_sec
	UserSettings.save_settings()
	Scenes.go_to(get_tree(), Scenes.MAIN_MENU)


func _show_intro() -> void:
	_phase = Phase.INTRO
	_indicator.text = "♪"
	_status.text = "Use headphones/speakers you play with.\nAfter 4 count-in clicks, tap on each of the next %d clicks." \
			% MEASURED_BEATS
	_start_button.grab_focus()


func _build_clock() -> void:
	_clock = SongClock.new()
	_clock.name = "SongClock"
	var player := AudioStreamPlayer.new()
	player.name = "Clicks"
	_clock.add_child(player)
	_clock.audio_player = player
	_clock.calibration_offset_sec = 0.0
	add_child(_clock)


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color(0.03, 0.01, 0.08)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Let screen taps fall through to _unhandled_input (mouse/touch calibration).
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 26)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(UiTheme.make_label("AUDIO CALIBRATION", 56, UiTheme.ACCENT))
	_indicator = UiTheme.make_label("", 96, UiTheme.HOT)
	column.add_child(_indicator)
	_status = UiTheme.make_label("", 30)
	column.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	_start_button = _add_button(buttons, "START", _start)
	_save_button = _add_button(buttons, "SAVE", _save)
	_retry_button = _add_button(buttons, "RETRY", _start)
	_add_button(buttons, "BACK", func() -> void: Scenes.go_to(get_tree(), Scenes.MAIN_MENU))
	_save_button.visible = false
	_retry_button.visible = false


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button: Button = UiTheme.make_button(text, 220.0)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
