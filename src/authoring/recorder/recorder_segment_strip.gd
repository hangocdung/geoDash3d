# Horizontal strip of segment buttons for the recorder (label + note count); the current one stays
# highlighted and scrolled into view. Related: src/authoring/recorder/recorder.gd, recorder_segments.gd
class_name RecorderSegmentStrip
extends ScrollContainer

signal chosen(index: int)

const BUTTON_SIZE: Vector2 = Vector2(150, 56)

var _buttons: Array[Button] = []
var _labels: PackedStringArray = []


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
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(func() -> void: chosen.emit(index))
		row.add_child(button)
		_buttons.append(button)
		_labels.append("%d  %s" % [index + 1, segments[index].label])


func set_current(index: int) -> void:
	_buttons[index].set_pressed_no_signal(true)
	ensure_control_visible.call_deferred(_buttons[index])


func set_counts(counts: PackedInt32Array) -> void:
	for index: int in _buttons.size():
		_buttons[index].text = "%s\n%d notes" % [_labels[index], counts[index]]
