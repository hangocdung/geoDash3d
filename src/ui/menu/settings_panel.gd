# Settings page, by category: GENERAL (quality, language, vibration, ad privacy in the EEA/UK), AUDIO (volumes, manual
# offset ±5 ms, auto sync, calibration), VISUAL (reduce flashing, music meter) and ABOUT. Categories are side tabs in
# landscape and a tab row in portrait; values go to UserSettings and are saved on BACK.
# Related: src/ui/menu/settings_rows.gd, src/core/user_settings.gd, src/ui/theme/ui_screen.gd
class_name SettingsPanel
extends UiScreen

const OFFSET_STEP_SEC: float = 0.005
const QUALITY_NAMES: PackedStringArray = ["LOW", "MEDIUM", "HIGH"]
const TABS: Array[Dictionary] = [{"id": &"general", "text": "GENERAL", "icon": &"gear"},
		{"id": &"audio", "text": "AUDIO", "icon": &"speaker"}, {"id": &"visual", "text": "VISUAL", "icon": &"eye"},
		{"id": &"about", "text": "ABOUT", "icon": &"info"}]
const LOGO: Texture2D = preload("res://assets/brand/logo.png")
const COMPANY_LOGO: Texture2D = preload("res://assets/brand/company.png")
const MUSIC_CREDIT: String = "Music generated with Google Flow Music (AI)"

var _split: BoxContainer
var _tab_bar: BoxContainer
var _tab_buttons: Dictionary[StringName, Button] = {}
var _content: VBoxContainer
var _current: StringName = &"general"


func _title() -> String:
	return "SETTINGS"


func _subtitle() -> String:
	return "CUSTOMIZE YOUR EXPERIENCE"


func _icon() -> StringName:
	return &"gear"


func _build_body() -> void:
	_split = BoxContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_theme_constant_override("separation", 28)
	body.add_child(_split)
	_tab_bar = BoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 14)
	_split.add_child(_tab_bar)
	var group := ButtonGroup.new()
	for tab: Dictionary in TABS:
		var button: Button = UiKit.button(tab["text"], tab["icon"], "TabButton", false, Vector2(300, 72))
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.button_pressed = tab["id"] == _current
		button.pressed.connect(_show_tab.bind(tab["id"]))
		_tab_bar.add_child(button)
		_tab_buttons[tab["id"]] = button
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)
	_tab_buttons[_current].grab_focus()


func _layout(is_portrait: bool) -> void:
	_split.vertical = is_portrait
	_tab_bar.vertical = not is_portrait
	for button: Button in _tab_buttons.values():
		button.custom_minimum_size = Vector2(0, 72) if is_portrait else Vector2(300, 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_portrait else Control.SIZE_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER if is_portrait else HORIZONTAL_ALIGNMENT_LEFT
	_show_tab(_current)


## Shows a category as if its tab was pressed (`id`: general, audio, visual, about).
func open_tab(id: StringName) -> void:
	if _tab_buttons.has(id):
		_tab_buttons[id].button_pressed = true
		_show_tab(id)


func _close() -> void:
	UserSettings.save_settings()
	super()


func _show_tab(id: StringName) -> void:
	_current = id
	for child: Node in _content.get_children():
		child.queue_free()
	var portrait: bool = UiKit.is_portrait(self)
	match id:
		&"general":
			_general(portrait)
		&"audio":
			_audio(portrait)
		&"visual":
			_visual(portrait)
		&"about":
			_about()


func _general(portrait: bool) -> void:
	var qualities: PackedStringArray = [Locale.t("AUTO (%s)") % Locale.t(QUALITY_NAMES[int(UserSettings.quality_tier)])]
	qualities.append_array(QUALITY_NAMES)
	var quality: OptionButton = SettingsRows.dropdown(qualities,
			0 if UserSettings.quality_auto else int(UserSettings.quality_tier) + 1, _on_quality_selected)
	_add(SettingsRows.row(&"gauge", "Graphics Quality", quality, portrait))
	var languages: PackedStringArray = ["AUTO"]
	for code: String in Locale.LANGUAGES:
		languages.append(Locale.NATIVE_NAMES[code])
	_add(SettingsRows.row(&"globe", "Language", SettingsRows.dropdown(languages,
			Locale.LANGUAGES.find(UserSettings.language) + 1, func(index: int) -> void:
				UserSettings.language = Locale.AUTO if index == 0 else Locale.LANGUAGES[index - 1]), portrait))
	_add(SettingsRows.row(&"vibrate", "Vibration", SettingsRows.switch("On PERFECT and crashes", UserSettings.haptics,
			func(enabled: bool) -> void: UserSettings.haptics = enabled), portrait))
	if Ads.privacy_options_required():
		var privacy: Button = UiKit.button("AD PRIVACY", &"privacy", "", false, Vector2(0, 60))
		privacy.pressed.connect(Ads.show_privacy_options)
		_add(SettingsRows.row(&"privacy", "Ads", privacy, portrait))


func _audio(portrait: bool) -> void:
	_add(SettingsRows.row(&"music", "Music Volume", SettingsRows.volume(UserSettings.music_volume_db,
			func(value: float) -> void: UserSettings.music_volume_db = value), portrait))
	_add(SettingsRows.row(&"speaker", "Effects Volume", SettingsRows.volume(UserSettings.sfx_volume_db,
			func(value: float) -> void:
				UserSettings.sfx_volume_db = value
				Sfx.play(&"ui.tap")), portrait))
	_add(SettingsRows.row(&"wave", "Audio Offset", SettingsRows.stepper(_offset_text(), func(direction: int) -> String:
		UserSettings.audio_offset_sec += OFFSET_STEP_SEC * direction
		return _offset_text()), portrait))
	_add(SettingsRows.row(&"link", "Auto Sync", SettingsRows.switch("Learn while playing", UserSettings.auto_offset,
			func(enabled: bool) -> void: UserSettings.auto_offset = enabled), portrait))
	var calibrate: Button = UiKit.button("CALIBRATE AUDIO", &"headphones", "", true, Vector2(0, 60))
	calibrate.pressed.connect(func() -> void:
		UserSettings.save_settings()
		Scenes.go_to(get_tree(), Scenes.CALIBRATION))
	_add(SettingsRows.row(&"headphones", "Calibration", calibrate, portrait))


func _visual(portrait: bool) -> void:
	_add(SettingsRows.row(&"eye", "Reduce Flashing", SettingsRows.switch("Calmer pulses, no sky pulse",
			UserSettings.reduce_flashing, func(enabled: bool) -> void: UserSettings.reduce_flashing = enabled), portrait))
	_add(SettingsRows.row(&"bars", "Music Meter", SettingsRows.switch("Spectrum + tap lane",
			UserSettings.show_music_meter, func(enabled: bool) -> void: UserSettings.show_music_meter = enabled), portrait))


func _about() -> void:
	_add(_picture(LOGO, 560.0))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	_add(spacer)
	_add(UiKit.label("A GAME BY", "Caption", HORIZONTAL_ALIGNMENT_CENTER))
	_add(_picture(COMPANY_LOGO, 300.0))
	var credit: Label = UiKit.label(MUSIC_CREDIT, "Muted", HORIZONTAL_ALIGNMENT_CENTER)
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(credit)
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	if not version.is_empty():
		_add(UiKit.label(Locale.t("Version %s") % version, "Muted", HORIZONTAL_ALIGNMENT_CENTER))


func _picture(texture: Texture2D, width: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(width, width * texture.get_height() / texture.get_width())
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _add(control: Control) -> void:
	_content.add_child(control)


## AUTO re-runs the menu benchmark from the platform default next time; a fixed tier disables it.
func _on_quality_selected(index: int) -> void:
	if index == 0:
		UserSettings.quality_auto = true
		UserSettings.quality_tier = QualityTier.default_for_platform()
	else:
		UserSettings.quality_auto = false
		UserSettings.quality_tier = QualityTier.from_int(index - 1)


func _offset_text() -> String:
	return "%+d ms" % roundi(UserSettings.audio_offset_sec * 1000.0)
