# Row builders for the settings page: icon + caption on the left, the control on the right (dropdown, slider with a
# percentage, − value + stepper, switch with its description). Related: src/ui/menu/settings_panel.gd
class_name SettingsRows
extends RefCounted

const ROW_HEIGHT: float = 76.0
const CAPTION_WIDTH: float = 340.0
const CAPTION_WIDTH_PORTRAIT: float = 280.0
const MIN_DB: float = -30.0


static func row(icon: StringName, caption: String, control: Control, portrait: bool) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	result.add_theme_constant_override("separation", 22)
	result.add_child(UiKit.icon_rect(icon, 34, UiTheme.ACCENT))
	var text: Label = UiKit.label(caption)
	text.add_theme_font_size_override("font_size", 28)
	text.custom_minimum_size = Vector2(CAPTION_WIDTH_PORTRAIT if portrait else CAPTION_WIDTH, 0)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_child(text)
	# A switch sits right after the caption with its description beside it, not stretched across the row.
	control.size_flags_horizontal = Control.SIZE_EXPAND if control is CheckButton else Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	result.add_child(control)
	return result


static func dropdown(items: PackedStringArray, selected: int, on_selected: Callable) -> OptionButton:
	var option := OptionButton.new()
	for item: String in items:
		option.add_item(item)
	option.select(selected)
	option.custom_minimum_size = Vector2(0, 60)
	option.item_selected.connect(on_selected)
	return option


## Volume in dB (−30…0) shown as 0–100 %.
static func volume(value_db: float, on_changed: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	var slider := HSlider.new()
	slider.min_value = MIN_DB
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = clampf(value_db, MIN_DB, 0.0)
	slider.custom_minimum_size = Vector2(240, 44)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(slider)
	var percent: Label = UiKit.label("", "", HORIZONTAL_ALIGNMENT_RIGHT)
	percent.custom_minimum_size = Vector2(92, 0)
	percent.add_theme_font_size_override("font_size", 26)
	box.add_child(percent)
	var show := func(value: float) -> void:
		percent.text = "%d%%" % roundi((value - MIN_DB) / -MIN_DB * 100.0)
	show.call(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		show.call(value)
		on_changed.call(value))
	return box


## − value + ; `step` callbacks return the new text.
static func stepper(text: String, on_step: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	var value: Label = UiKit.label(text, "BigNumber", HORIZONTAL_ALIGNMENT_CENTER)
	value.add_theme_font_size_override("font_size", 30)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for direction: int in [-1, 1]:
		var button: Button = UiTheme.make_button("−" if direction < 0 else "+", 64.0, 60.0)
		button.theme_type_variation = "IconButton"
		button.pressed.connect(func() -> void: value.text = on_step.call(direction))
		box.add_child(button)
		if direction < 0:
			box.add_child(value)
	return box


static func switch(description: String, enabled: bool, on_toggled: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = description
	toggle.button_pressed = enabled
	toggle.toggled.connect(on_toggled)
	# Right-to-left puts the switch first and the description after it.
	toggle.layout_direction = Control.LAYOUT_DIRECTION_RTL
	toggle.text_direction = Control.TEXT_DIRECTION_LTR
	return toggle
