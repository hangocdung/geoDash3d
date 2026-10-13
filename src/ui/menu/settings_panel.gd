# Settings panel: quality tier, music volume and manual audio offset (±5 ms), saved to UserSettings.
# Related: src/core/user_settings.gd, src/ui/menu/main_menu.gd
class_name SettingsPanel
extends PanelContainer

signal closed

const OFFSET_STEP_SEC: float = 0.005
const QUALITY_NAMES: PackedStringArray = ["LOW", "MEDIUM", "HIGH"]

var _offset_label: Label
var _quality: OptionButton
var _volume: HSlider


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	add_child(column)
	column.add_child(UiTheme.make_label("SETTINGS", 48, UiTheme.ACCENT))

	_quality = OptionButton.new()
	for index: int in QUALITY_NAMES.size():
		_quality.add_item(QUALITY_NAMES[index], index)
	_quality.select(int(UserSettings.quality_tier))
	_quality.item_selected.connect(func(index: int) -> void:
		UserSettings.quality_tier = QualityTier.from_int(index))
	column.add_child(_row("Graphics (next run)", _quality))

	_volume = HSlider.new()
	_volume.min_value = -30.0
	_volume.max_value = 0.0
	_volume.step = 1.0
	_volume.value = clampf(UserSettings.music_volume_db, -30.0, 0.0)
	_volume.custom_minimum_size = Vector2(320, 40)
	_volume.value_changed.connect(func(value: float) -> void: UserSettings.music_volume_db = value)
	column.add_child(_row("Music volume", _volume))

	var effects: HSlider = _volume_slider(UserSettings.sfx_volume_db)
	effects.value_changed.connect(func(value: float) -> void:
		UserSettings.sfx_volume_db = value
		Sfx.play(&"ui.tap"))
	column.add_child(_row("Effects volume", effects))

	var offset_box := HBoxContainer.new()
	offset_box.add_theme_constant_override("separation", 12)
	offset_box.add_child(_small_button("−", func() -> void: _change_offset(-OFFSET_STEP_SEC)))
	_offset_label = UiTheme.make_label("", 30)
	_offset_label.custom_minimum_size = Vector2(140, 0)
	offset_box.add_child(_offset_label)
	offset_box.add_child(_small_button("+", func() -> void: _change_offset(OFFSET_STEP_SEC)))
	column.add_child(_row("Audio offset", offset_box))
	_refresh_offset()

	var back: Button = UiTheme.make_button("BACK", 300.0, 72.0, &"ui.back")
	back.pressed.connect(_close)
	column.add_child(back)
	back.grab_focus()


func _close() -> void:
	UserSettings.save_settings()
	closed.emit()


func _change_offset(step_sec: float) -> void:
	UserSettings.audio_offset_sec += step_sec
	_refresh_offset()


func _refresh_offset() -> void:
	_offset_label.text = "%+d ms" % roundi(UserSettings.audio_offset_sec * 1000.0)


func _volume_slider(value_db: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = -30.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = clampf(value_db, -30.0, 0.0)
	slider.custom_minimum_size = Vector2(320, 40)
	return slider


func _row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var label := UiTheme.make_label(caption, 30)
	label.custom_minimum_size = Vector2(320, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(label)
	row.add_child(control)
	return row


func _small_button(text: String, action: Callable) -> Button:
	var button: Button = UiTheme.make_button(text, 72.0)
	button.pressed.connect(action)
	return button
