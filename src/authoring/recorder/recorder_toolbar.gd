# On-screen controls of the recorder: transport, segment navigation, speed/grid, editing, save/build, and
# one big TAP pad that fires on press. Buttons never take keyboard focus (Space is a tap).
# Emits intents only; Recorder owns the state. Related: src/authoring/recorder/recorder.gd
class_name RecorderToolbar
extends VBoxContainer

signal action(name: StringName)
signal rate_chosen(index: int)
signal grid_chosen(index: int)
signal pad_down

const FONT_SIZE: int = 18
const ROW_HEIGHT: float = 46.0
const PAD_HEIGHT: float = 76.0

var _buttons: Dictionary[StringName, Button] = {}
var _rate_buttons: Array[Button] = []
var _grid_buttons: Array[Button] = []


func setup(rates: Array[float], grids: Array[float]) -> void:
	add_theme_constant_override("separation", 8)
	var transport: HBoxContainer = _row()
	_add(transport, &"start", "|< SEGMENT START", 190)
	_add(transport, &"back_beat", "< 1 BEAT", 110)
	_add(transport, &"play", "PLAY", 120)
	_add(transport, &"forward_beat", "1 BEAT >", 110)
	_add(transport, &"previous_segment", "<< PREV", 110)
	_add(transport, &"next_segment", "NEXT >>", 110)
	_add(transport, &"loop", "LOOP", 100, true)
	_add(transport, &"preroll", "PRE-ROLL", 120, true)
	_add(transport, &"record", "REC", 90, true)
	var timing: HBoxContainer = _row()
	timing.add_child(_caption("SPEED"))
	var rate_group := ButtonGroup.new()
	for index: int in rates.size():
		var button: Button = _make("%d%%" % roundi(rates[index] * 100.0), 76)
		button.toggle_mode = true
		button.button_group = rate_group
		button.pressed.connect(func() -> void: rate_chosen.emit(index))
		timing.add_child(button)
		_rate_buttons.append(button)
	timing.add_child(_caption("GRID"))
	var grid_group := ButtonGroup.new()
	for index: int in grids.size():
		var button: Button = _make("1/%d" % roundi(1.0 / grids[index]), 66)
		button.toggle_mode = true
		button.button_group = grid_group
		button.pressed.connect(func() -> void: grid_chosen.emit(index))
		timing.add_child(button)
		_grid_buttons.append(button)
	timing.add_child(_caption("EDIT"))
	_add(timing, &"delete", "DELETE", 100)
	_add(timing, &"align", "ALIGN TIMING", 150)
	_add(timing, &"clear_segment", "CLEAR SEGMENT", 170)
	var files: HBoxContainer = _row()
	_add(files, &"undo", "UNDO", 90)
	_add(files, &"redo", "REDO", 90)
	_add(files, &"save", "SAVE", 100)
	if not OS.has_feature("mobile"):
		_add(files, &"build", "BUILD & PLAY SEGMENT", 250)
	_add(files, &"exit", "EXIT", 100)
	var pads: HBoxContainer = _row()
	var pad: Button = _make("TAP  [Space / J]   -   the player acts here", 300)
	pad.custom_minimum_size.y = PAD_HEIGHT
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_color_override("font_color", RecorderTimeline.TAP_COLOR)
	pad.button_down.connect(func() -> void: pad_down.emit())
	pads.add_child(pad)


func set_playing(playing: bool) -> void:
	_buttons[&"play"].text = "PAUSE" if playing else "PLAY"


func set_toggle(name: StringName, on: bool) -> void:
	_buttons[name].set_pressed_no_signal(on)


func set_enabled(name: StringName, enabled: bool) -> void:
	if _buttons.has(name):
		_buttons[name].disabled = not enabled


func set_rate(index: int) -> void:
	_rate_buttons[index].set_pressed_no_signal(true)


func set_grid(index: int) -> void:
	_grid_buttons[index].set_pressed_no_signal(true)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	return row


func _add(row: HBoxContainer, name: StringName, text: String, width: float, toggle: bool = false) -> Button:
	var button: Button = _make(text, width)
	button.toggle_mode = toggle
	button.pressed.connect(func() -> void: action.emit(name))
	row.add_child(button)
	_buttons[name] = button
	return button


func _make(text: String, width: float) -> Button:
	var button: Button = UiTheme.make_button(text, width, ROW_HEIGHT, &"")
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var style: StyleBox = UiTheme.get_theme().get_stylebox(state, "Button")
		if UiTheme.get_theme().has_stylebox(state, "Button"):
			var compact: StyleBox = style.duplicate()
			compact.content_margin_left = 8
			compact.content_margin_right = 8
			compact.content_margin_top = 4
			compact.content_margin_bottom = 4
			button.add_theme_stylebox_override(state, compact)
	return button


func _caption(text: String) -> Label:
	var label: Label = UiTheme.make_label(text, 15, Color(0.6, 0.65, 0.85))
	label.custom_minimum_size.x = 64
	return label
