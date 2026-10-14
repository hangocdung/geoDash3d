# Horizontal strip of segment buttons for the recorder (text and color set by the recorder: name, time range,
# notes vs suggestion); the current one stays highlighted and scrolled into view.
# Related: src/authoring/recorder/recorder.gd, recorder_segments.gd
class_name RecorderSegmentStrip
extends ScrollContainer

signal chosen(index: int)

const BUTTON_SIZE: Vector2 = Vector2(168, 78)
## Note counts below/above these shares of the suggestion are flagged.
const UNDER_RATIO: float = 0.7
const OVER_RATIO: float = 1.3

var _buttons: Array[Button] = []


func setup(segments: Array[RecorderSegments.Segment]) -> void:
	custom_minimum_size.y = BUTTON_SIZE.y + 10
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var group := ButtonGroup.new()
	for index: int in segments.size():
		var button: Button = UiTheme.make_button("", BUTTON_SIZE.x, BUTTON_SIZE.y, &"")
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(func() -> void: chosen.emit(index))
		row.add_child(button)
		_buttons.append(button)


func set_current(index: int) -> void:
	_buttons[index].set_pressed_no_signal(true)
	ensure_control_visible.call_deferred(_buttons[index])


## `entries`: per segment Vector4(start_sec, end_sec, notes, suggested notes). Colors: grey = empty,
## blue = well under the suggestion, green = close to it, orange = well over it.
func refresh(segments: Array[RecorderSegments.Segment], entries: Array[Vector4]) -> void:
	for index: int in _buttons.size():
		var entry: Vector4 = entries[index]
		var notes: int = int(entry.z)
		var suggested: int = int(entry.w)
		var color: Color = UiTheme.TEXT
		if notes == 0:
			color = Color(0.55, 0.55, 0.65)
		elif notes < suggested * UNDER_RATIO:
			color = Color(0.45, 0.7, 1.0)
		elif notes > suggested * OVER_RATIO + 1:
			color = Color(1.0, 0.65, 0.3)
		else:
			color = Color(0.55, 1.0, 0.55)
		var button: Button = _buttons[index]
		button.text = "%d  %s\n%s - %s\n%d / ~%d notes" % [index + 1, segments[index].label, _clock_text(entry.x),
				_clock_text(entry.y), notes, suggested]
		for state: String in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, color)


static func _clock_text(time_sec: float) -> String:
	var tenths: int = roundi(maxf(time_sec, 0.0) * 10.0)
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]
