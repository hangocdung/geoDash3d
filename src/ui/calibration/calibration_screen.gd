# Audio sync calibration: one identical click at 100 BPM; the player taps on every click from the start.
# The first taps (warm-up) are ignored silently, the ring pulses only for the first clicks (then ears
# only), and the robust mean error of 16 taps becomes UserSettings.audio_offset_sec.
# Related: pulse_ring.gd, src/core/calibration_math.gd, src/core/audio/click_track.gd
class_name CalibrationScreen
extends Control

enum Phase { INTRO, RUNNING, RESULT }

const BPM: float = 100.0
const FIRST_CLICK_SEC: float = 1.0
## Taps ignored while the player settles into the rhythm.
const WARMUP_TAPS: int = 4
const MEASURED_TAPS: int = 16
## The ring pulses with the first clicks to teach the rhythm; afterwards the player listens only.
const GUIDE_CLICKS: int = 6
const MAX_CLICKS: int = 48
const MAX_ACCEPTED_ERROR_SEC: float = 0.25
const MAX_GOOD_SPREAD_SEC: float = 0.04

var _phase: Phase = Phase.INTRO
var _tempo: TempoMap
var _clicks: AudioStreamWAV
var _clock: SongClock
var _errors: PackedFloat64Array = []
var _tapped_beats: Dictionary[int, bool] = {}
var _accepted_taps: int = 0
var _last_click: int = -1
var _estimate: CalibrationMath.Estimate
var _ring: PulseRing
var _headline: Label
var _counter: Label
var _status: Label
var _start_button: Button
var _use_button: Button
var _retry_button: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tempo = TempoMap.constant(BPM, FIRST_CLICK_SEC)
	_clicks = ClickTrack.generate(_tempo, _tempo.beat_to_time(float(MAX_CLICKS)) + 0.5, 4, false)
	_build_clock()
	_build_layout()
	_show_intro()


func _process(_delta: float) -> void:
	if _phase != Phase.RUNNING:
		return
	var beat: float = _tempo.time_to_beat(_clock.frame_time())
	var click: int = int(floorf(beat))
	if beat >= 0.0 and click != _last_click:
		_last_click = click
		if click < GUIDE_CLICKS:
			_ring.pulse = 1.0
		elif click == GUIDE_CLICKS:
			_headline.text = "Keep tapping — just listen"
	if _errors.size() >= MEASURED_TAPS or beat > MAX_CLICKS + 0.5:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.RUNNING or not event.is_action_pressed(&"tap", false, true):
		return
	get_viewport().set_input_as_handled()
	_ring.flash = 1.0
	var tap_time: float = _clock.now()
	var beat: int = roundi(_tempo.time_to_beat(tap_time))
	if beat < 0 or beat >= MAX_CLICKS or _tapped_beats.has(beat):
		return
	var error: float = CalibrationMath.tap_error(tap_time, _tempo)
	if absf(error) > MAX_ACCEPTED_ERROR_SEC:
		return
	_tapped_beats[beat] = true
	_accepted_taps += 1
	if _accepted_taps > WARMUP_TAPS:
		_errors.append(error)
	_counter.text = "%d / %d" % [mini(_accepted_taps, WARMUP_TAPS + MEASURED_TAPS), WARMUP_TAPS + MEASURED_TAPS]


func _start() -> void:
	_phase = Phase.RUNNING
	_errors.clear()
	_tapped_beats.clear()
	_accepted_taps = 0
	_last_click = -1
	_set_buttons(false, false, false)
	_headline.text = "Tap on every click"
	_counter.text = "0 / %d" % (WARMUP_TAPS + MEASURED_TAPS)
	_status.text = "Tap anywhere on the screen, in time with the sound."
	_clock.start(_clicks, 0.0, 0.3)


func _finish() -> void:
	_phase = Phase.RESULT
	_clock.stop()
	_estimate = CalibrationMath.estimate(_errors)
	_counter.text = ""
	if not _estimate.is_valid:
		_headline.text = "Let's try again"
		_status.text = "Not enough taps landed on the clicks.\nTap once for every click you hear."
		_set_buttons(false, false, true)
		return
	var offset_ms: int = roundi(_estimate.offset_sec * 1000.0)
	var steady: bool = _estimate.spread_sec <= MAX_GOOD_SPREAD_SEC
	print("CALIBRATION offset_ms=%d spread_ms=%d taps=%d engine_latency_ms=%.1f" % [offset_ms,
			roundi(_estimate.spread_sec * 1000.0), _estimate.accepted_count, AudioServer.get_output_latency() * 1000.0])
	_headline.text = "Audio delay: %+d ms" % offset_ms
	_status.text = "%s\nThe game will shift its timing by this amount so notes match what you hear." % (
			"Your taps were nice and steady." if steady else "Your taps were a bit uneven — trying again may be more accurate.")
	_set_buttons(false, true, true)
	_use_button.grab_focus()


func _use_result() -> void:
	if _estimate == null or not _estimate.is_valid:
		return
	UserSettings.audio_offset_sec = _estimate.offset_sec
	UserSettings.save_settings()
	Scenes.go_to(get_tree(), Scenes.MAIN_MENU)


func _show_intro() -> void:
	_phase = Phase.INTRO
	_headline.text = "Tap on every click"
	_counter.text = ""
	_status.text = "You will hear a steady click. Tap the screen each time you hear it.\n" \
			+ "Use the speakers or headphones you play with.   Current delay: %+d ms" % roundi(
			UserSettings.audio_offset_sec * 1000.0)
	_set_buttons(true, false, false)
	_start_button.grab_focus()


func _set_buttons(start_visible: bool, use_visible: bool, retry_visible: bool) -> void:
	_start_button.visible = start_visible
	_use_button.visible = use_visible
	_retry_button.visible = retry_visible


func _build_clock() -> void:
	_clock = SongClock.new()
	_clock.name = "SongClock"
	var player := AudioStreamPlayer.new()
	player.name = "Clicks"
	player.bus = AudioBuses.UI
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
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	column.add_child(UiTheme.make_label("AUDIO SYNC", 44, UiTheme.ACCENT))
	_headline = UiTheme.make_label("", 52, Color.WHITE)
	column.add_child(_headline)
	_ring = PulseRing.new()
	_ring.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_ring)
	_counter = UiTheme.make_label("", 40, UiTheme.HOT)
	column.add_child(_counter)
	_status = UiTheme.make_label("", 28)
	column.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	_start_button = _add_button(buttons, "START", _start, &"ui.confirm")
	_use_button = _add_button(buttons, "USE THIS", _use_result, &"ui.confirm")
	_retry_button = _add_button(buttons, "TRY AGAIN", _start, &"ui.tap")
	_add_button(buttons, "BACK", func() -> void: Scenes.go_to(get_tree(), Scenes.MAIN_MENU), &"ui.back")


func _add_button(parent: Control, text: String, action: Callable, sound_id: StringName) -> Button:
	var button: Button = UiTheme.make_button(text, 240.0, 72.0, sound_id)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
