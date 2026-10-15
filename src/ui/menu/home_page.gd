# Home page of the title screen: the logo, a "now playing" tag and the menu entries (icon + text + chevron) on the
# dark left side of the attract level in landscape, centred in portrait; QUIT bottom-right on desktop. MainMenu opens
# the pages; this only reports which entry was pressed. Related: src/ui/menu/main_menu.gd, src/ui/theme/ui_kit.gd
class_name HomePage
extends Control

## `action`: play, practice, calibrate, sync, settings, shop, record, autoplay.
signal action_pressed(action: StringName)

## BeatGlide title logo (tools/branding/build_brand.py).
const LOGO: Texture2D = preload("res://assets/brand/logo.png")
## Menu column width on the 1920×1080 landscape / 1080×1920 portrait UI canvas.
const MENU_WIDTH: float = 640.0
const MENU_WIDTH_PORTRAIT: float = 860.0
const BACKDROP_COLOR: Color = Color(0.02, 0.0, 0.07)

var _menu_column: VBoxContainer
var _backdrop: TextureRect
var _logo: TextureRect
var _now_playing_pill: PanelContainer
var _now_playing_title: Label
var _quit_button: Button
var _buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_backdrop()
	_build_menu()
	_layout()
	get_viewport().size_changed.connect(_layout)


## Keyboard / gamepad focus back on an entry (after a page closes).
func focus(action: StringName) -> void:
	if _buttons.has(action):
		_buttons[action].grab_focus()


## Landscape: dark on the left behind the menu, the attract level clear on the right. Portrait: an even shade.
func _build_backdrop() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BACKDROP_COLOR, 0.88))
	gradient.set_color(1, Color(BACKDROP_COLOR, 0.0))
	gradient.add_point(0.45, Color(BACKDROP_COLOR, 0.6))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	_backdrop = TextureRect.new()
	_backdrop.texture = texture
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)


func _build_menu() -> void:
	_menu_column = VBoxContainer.new()
	_menu_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_column.add_theme_constant_override("separation", 14)
	add_child(_menu_column)
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_column.add_child(_logo)
	_now_playing_pill = _now_playing()
	_menu_column.add_child(_now_playing_pill)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_menu_column.add_child(spacer)
	_add_button("PLAY", &"play", &"play", &"ui.confirm", "PrimaryButton")
	_add_button("PRACTICE", &"target", &"practice")
	_add_button("CALIBRATE AUDIO", &"headphones", &"calibrate")
	_add_button("SYNC TEST", &"wave", &"sync")
	_add_button("SETTINGS", &"gear", &"settings")
	_add_button("SHOP", &"cart", &"shop")
	if OS.is_debug_build():
		# Two dev tools share a row so the menu keeps its height.
		var dev_row := HBoxContainer.new()
		dev_row.add_theme_constant_override("separation", 14)
		_menu_column.add_child(dev_row)
		_add_small_button("RECORD (DEV)", &"record", &"record", dev_row)
		_add_small_button("AUTOPLAY (DEV)", &"play", &"autoplay", dev_row)
	if not OS.has_feature("mobile"):
		_quit_button = UiKit.button("QUIT", &"power", "", false, Vector2(240, 64))
		_quit_button.pressed.connect(func() -> void: get_tree().quit())
		add_child(_quit_button)
	_buttons[&"play"].grab_focus()


## "Now playing" tag under the logo: the attract level's song.
func _now_playing() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.theme_type_variation = "Pill"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pill.add_child(row)
	row.add_child(UiKit.icon_rect(&"music", 26, UiTheme.HOT))
	_now_playing_title = UiKit.label("")
	_now_playing_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_now_playing_title.add_theme_font_size_override("font_size", 24)
	_now_playing_title.add_theme_color_override("font_color", UiTheme.HOT)
	row.add_child(_now_playing_title)
	return pill


## The attract level's song title (the song list may have switched it).
func set_now_playing(title: String) -> void:
	_now_playing_title.text = title.to_upper()
	_now_playing_pill.visible = not title.is_empty()


func _layout() -> void:
	var portrait: bool = UiKit.is_portrait(self)
	var margins: Vector4 = UiKit.safe_margins(self)
	var width: float = MENU_WIDTH_PORTRAIT if portrait else MENU_WIDTH
	# Touch landscape: finger-sized entries take the height, the logo gives some back.
	var logo_width: float = width * 0.82 if UiTheme.touch_ui() and not portrait else width
	_logo.custom_minimum_size = Vector2(logo_width, logo_width * LOGO.get_height() / LOGO.get_width())
	_now_playing_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_SHRINK_BEGIN
	for child: Node in _menu_column.get_children():
		if child is Button:
			(child as Button).custom_minimum_size.x = width
	var texture: GradientTexture2D = _backdrop.texture as GradientTexture2D
	if portrait:
		_menu_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_menu_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_menu_column.grow_vertical = Control.GROW_DIRECTION_BOTH
		# A zero-length fill gives the first colour everywhere: an even shade.
		texture.fill_to = Vector2.ZERO
		_backdrop.modulate = Color(1, 1, 1, 0.6)
	else:
		_menu_column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		_menu_column.offset_left = margins.x + 60.0
		_menu_column.offset_right = margins.x + 60.0 + width
		_menu_column.offset_top = margins.y
		_menu_column.offset_bottom = -margins.w
		texture.fill_to = Vector2(1.0, 0.0)
		_backdrop.modulate = Color.WHITE
	if _quit_button != null:
		_quit_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		_quit_button.offset_left = -margins.z - 240.0
		_quit_button.offset_right = -margins.z
		_quit_button.offset_top = -margins.w - 64.0
		_quit_button.offset_bottom = -margins.w
		_quit_button.visible = not portrait


## Menu entry: icon, text, chevron.
func _add_button(text: String, icon: StringName, action: StringName, sound_id: StringName = &"ui.tap",
		variation: String = "") -> void:
	var button: Button = UiKit.button(text, icon, variation, true, Vector2(MENU_WIDTH, 68), sound_id)
	button.pressed.connect(func() -> void: action_pressed.emit(action))
	_menu_column.add_child(button)
	_buttons[action] = button


func _add_small_button(text: String, icon: StringName, action: StringName, row: HBoxContainer) -> void:
	var button: Button = UiKit.button(text, icon, "SmallButton", false, Vector2(0, 54))
	button.custom_minimum_size.y = UiTheme.touch_height(54.0, 76.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: action_pressed.emit(action))
	row.add_child(button)
	_buttons[action] = button
