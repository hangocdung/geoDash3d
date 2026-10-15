# Shared neon UI theme built in code so every screen looks consistent: dark glass panels with a cyan glow edge,
# magenta primary buttons, side tabs, list rows, sliders, switches and dropdowns. Type variations (theme_type_variation)
# name the roles: PrimaryButton, TabButton, RowButton, IconButton, SmallButton, Card, Dialog, Row, HeaderTitle, …
# Related: src/ui/theme/ui_kit.gd (builders), src/ui/theme/ui_icons.gd
class_name UiTheme
extends RefCounted

const TEXT: Color = Color(0.9, 0.96, 1.0)
const MUTED: Color = Color(0.62, 0.68, 0.88)
const ACCENT: Color = Color(0.22, 0.9, 1.0)
const HOT: Color = Color(1.0, 0.3, 0.85)
const VIOLET: Color = Color(0.55, 0.4, 1.0)
const PANEL: Color = Color(0.035, 0.03, 0.12, 0.86)
const PANEL_SOFT: Color = Color(0.06, 0.05, 0.18, 0.78)
const PRIMARY: Color = Color(0.78, 0.16, 0.86)
const PRIMARY_HOVER: Color = Color(0.92, 0.26, 0.95)
const SUCCESS: Color = Color(0.55, 0.95, 0.35)
## Difficulty badge colours by ChartDifficulty tier name.
const TIER_COLORS: Dictionary[String, Color] = {"EASY": Color(0.5, 0.85, 0.2), "NORMAL": Color(0.15, 0.6, 1.0),
		"HARD": Color(0.95, 0.25, 0.35), "HARDER": Color(0.95, 0.45, 0.15), "EXPERT": Color(0.7, 0.3, 1.0)}
const RADIUS: int = 12
## Touch screens: interactive controls are at least this tall (canvas units; about 7 mm on a 1080p-tall phone).
const TOUCH_MIN_HEIGHT: float = 96.0
## `-- --touch-ui` forces touch sizes on PC (screenshots of the phone layout).
const TOUCH_ARGUMENT: String = "--touch-ui"

static var _cached: Theme
static var _touch: int = -1


static func get_theme() -> Theme:
	if _cached != null:
		return _cached
	var theme := Theme.new()
	theme.default_font = _font(0.45)
	theme.default_font_size = 30
	_buttons(theme)
	_panels(theme)
	_labels(theme)
	_inputs(theme)
	_cached = theme
	return theme


## Bolder face for titles and big numbers.
static func heading_font() -> Font:
	return _font(0.95)


## True on phones / tablets and touch-screen PCs: controls get finger-sized (touch_height).
static func touch_ui() -> bool:
	if _touch < 0:
		_touch = 1 if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() 				or OS.get_cmdline_user_args().has(TOUCH_ARGUMENT) else 0
	return _touch == 1


## `height` raised to a finger-sized `minimum` on touch screens (unchanged with a mouse).
static func touch_height(height: float, minimum: float = TOUCH_MIN_HEIGHT) -> float:
	return maxf(height, minimum) if touch_ui() and height > 0.0 else height


## `pixels` scaled up on touch screens (icons, knobs, gaps).
static func touch_scaled(pixels: int, scale: float = 1.35) -> int:
	return roundi(pixels * scale) if touch_ui() else pixels


static func make_button(text: String, minimum_width: float = 420.0, height: float = 72.0,
		sound_id: StringName = &"ui.tap") -> Button:
	var button := Button.new()
	button.text = text
	var tall: float = touch_height(height)
	# Narrow icon buttons (− / +, pause) grow into squares so they stay hittable.
	var wide: float = maxf(minimum_width, tall) if touch_ui() and minimum_width > 0.0 and minimum_width < tall 			else minimum_width
	button.custom_minimum_size = Vector2(wide, tall)
	if not sound_id.is_empty():
		button.pressed.connect(func() -> void: Sfx.play(sound_id))
	return button


static func make_label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## Flat box: `glow` > 0 adds a soft shadow in the border colour (neon edge).
static func box(background: Color, border: Color, border_width: int, glow: int = 0, radius: int = RADIUS) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.corner_detail = 6
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if glow > 0:
		style.shadow_color = Color(border, 0.35)
		style.shadow_size = glow
	return style


static func _font(embolden: float) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = embolden
	return font


static func _buttons(theme: Theme) -> void:
	var edge: Color = Color(ACCENT, 0.75)
	_button_styles(theme, "Button", box(PANEL, edge, 2, 4), box(Color(0.08, 0.1, 0.26, 0.92), ACCENT, 2, 10),
			box(Color(0.1, 0.25, 0.4, 0.95), ACCENT, 3, 12), box(Color(PANEL, 0.6), Color(0.35, 0.35, 0.5, 0.6), 2))
	theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.85), 2))
	for state: String in ["font_color", "font_focus_color"]:
		theme.set_color(state, "Button", TEXT)
	for state: String in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	theme.set_constant("h_separation", "Button", 18)
	theme.set_constant("icon_max_width", "Button", 40)

	theme.set_type_variation("PrimaryButton", "Button")
	_button_styles(theme, "PrimaryButton", box(PRIMARY, Color(1.0, 0.55, 0.95), 2, 12),
			box(PRIMARY_HOVER, Color(1.0, 0.75, 1.0), 2, 18), box(Color(0.6, 0.1, 0.7), Color.WHITE, 3, 18),
			box(Color(0.35, 0.15, 0.4, 0.7), Color(0.6, 0.4, 0.65, 0.6), 2))

	theme.set_type_variation("TabButton", "Button")
	_button_styles(theme, "TabButton", box(PANEL_SOFT, Color(VIOLET, 0.35), 1),
			box(Color(0.1, 0.08, 0.28, 0.9), Color(ACCENT, 0.7), 2, 6), box(PRIMARY, Color(1.0, 0.55, 0.95), 2, 12),
			box(PANEL_SOFT, Color(0.3, 0.3, 0.4, 0.4), 1))
	theme.set_stylebox("hover_pressed", "TabButton", box(PRIMARY_HOVER, Color(1.0, 0.75, 1.0), 2, 14))

	theme.set_type_variation("RowButton", "Button")
	var row_margin: float = 14.0
	var row_styles: Array[StyleBoxFlat] = [box(PANEL, Color(VIOLET, 0.55), 2, 4), box(Color(0.08, 0.06, 0.24, 0.94), HOT, 3, 14),
			box(Color(0.14, 0.06, 0.3, 0.96), HOT, 3, 16), box(Color(PANEL, 0.7), Color(0.3, 0.3, 0.45, 0.5), 2)]
	for style: StyleBoxFlat in row_styles:
		style.set_content_margin_all(row_margin)
	_button_styles(theme, "RowButton", row_styles[0], row_styles[1], row_styles[2], row_styles[3])

	theme.set_type_variation("IconButton", "Button")
	var square: Array[StyleBoxFlat] = [box(PANEL, edge, 2, 4), box(Color(0.08, 0.1, 0.26, 0.92), ACCENT, 2, 10),
			box(Color(0.1, 0.25, 0.4, 0.95), ACCENT, 3, 12), box(Color(PANEL, 0.6), Color(0.35, 0.35, 0.5, 0.6), 2)]
	for style: StyleBoxFlat in square:
		style.set_content_margin_all(10)
	_button_styles(theme, "IconButton", square[0], square[1], square[2], square[3])

	theme.set_type_variation("SmallButton", "Button")
	theme.set_font_size("font_size", "SmallButton", 22)


static func _button_styles(theme: Theme, type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox,
		disabled: StyleBox) -> void:
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hover)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("hover_pressed", type, pressed)
	theme.set_stylebox("disabled", type, disabled)


static func _panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, Color(VIOLET, 0.8), 2, 6))
	var card: StyleBoxFlat = box(PANEL, Color(ACCENT, 0.55), 2, 10, 16)
	card.set_content_margin_all(32)
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", card)
	var dialog: StyleBoxFlat = box(Color(0.04, 0.03, 0.14, 0.96), Color(HOT, 0.8), 2, 18, 18)
	dialog.set_content_margin_all(40)
	theme.set_type_variation("Dialog", "PanelContainer")
	theme.set_stylebox("panel", "Dialog", dialog)
	var row: StyleBoxFlat = box(PANEL, Color(VIOLET, 0.55), 2, 4)
	row.set_content_margin_all(14)
	theme.set_type_variation("Row", "PanelContainer")
	theme.set_stylebox("panel", "Row", row)
	var pill: StyleBoxFlat = box(Color(0.03, 0.02, 0.1, 0.7), Color(HOT, 0.6), 1, 0, 24)
	pill.content_margin_top = 6
	pill.content_margin_bottom = 6
	theme.set_type_variation("Pill", "PanelContainer")
	theme.set_stylebox("panel", "Pill", pill)
	theme.set_type_variation("Badge", "PanelContainer")
	var badge: StyleBoxFlat = box(Color.WHITE, Color.WHITE, 0, 0, 6)
	badge.content_margin_left = 14
	badge.content_margin_right = 14
	badge.content_margin_top = 2
	badge.content_margin_bottom = 2
	theme.set_stylebox("panel", "Badge", badge)
	var scroll_grabber: StyleBoxFlat = box(Color(ACCENT, 0.6), Color(ACCENT, 0.6), 0, 0, 4)
	# Thick enough to grab with a finger; the list also scrolls by dragging its rows (TouchScroll).
	scroll_grabber.set_content_margin_all(touch_scaled(7, 1.8))
	var scroll_track: StyleBoxFlat = box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 0, 4)
	scroll_track.set_content_margin_all(touch_scaled(7, 1.8))
	theme.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber)
	theme.set_stylebox("grabber_pressed", "VScrollBar", scroll_grabber)
	theme.set_stylebox("scroll", "VScrollBar", scroll_track)


static func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_outline_color", "Label", Color(0.03, 0.0, 0.08, 0.9))
	theme.set_constant("outline_size", "Label", 6)
	var roles: Dictionary[String, Array] = {
		"HeaderTitle": [64, TEXT, true], "HeaderSubtitle": [22, HOT, false], "SectionTitle": [40, ACCENT, true],
		"Caption": [20, ACCENT, false], "Muted": [24, MUTED, false], "BigNumber": [36, Color.WHITE, true],
	}
	for role: String in roles:
		var spec: Array = roles[role]
		theme.set_type_variation(role, "Label")
		theme.set_font_size("font_size", role, spec[0])
		theme.set_color("font_color", role, spec[1])
		if spec[2]:
			theme.set_font("font", role, heading_font())


static func _inputs(theme: Theme) -> void:
	var field: StyleBoxFlat = box(Color(0.02, 0.02, 0.08, 0.9), Color(ACCENT, 0.6), 2, 0, 10)
	var field_hover: StyleBoxFlat = box(Color(0.06, 0.06, 0.18, 0.95), ACCENT, 2, 8, 10)
	_button_styles(theme, "OptionButton", field, field_hover, field_hover, field)
	theme.set_stylebox("focus", "OptionButton", box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.85), 2, 0, 10))
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", Color.WHITE)
	theme.set_font_size("font_size", "OptionButton", 26)
	theme.set_icon("arrow", "OptionButton", UiIcons.get_icon(&"chevron_down", 26, ACCENT))
	var popup: StyleBoxFlat = box(Color(0.03, 0.03, 0.12, 0.98), ACCENT, 2, 10, 10)
	popup.set_content_margin_all(10)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", box(Color(PRIMARY, 0.85), Color(0, 0, 0, 0), 0, 0, 8))
	theme.set_font_size("font_size", "PopupMenu", touch_scaled(28, 1.15))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_constant("v_separation", "PopupMenu", touch_scaled(14, 2.2))
	theme.set_icon("radio_checked", "PopupMenu", UiIcons.get_icon(&"check", 24, ACCENT))
	theme.set_icon("radio_unchecked", "PopupMenu", PlaceholderTexture2D.new())

	var track: StyleBoxFlat = box(Color(0.1, 0.08, 0.24), Color(0, 0, 0, 0), 0, 0, 6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	theme.set_stylebox("slider", "HSlider", track)
	var fill: StyleBoxFlat = box(ACCENT, Color(0, 0, 0, 0), 0, 0, 6)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	fill.shadow_color = Color(ACCENT, 0.4)
	fill.shadow_size = 6
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	theme.set_icon("grabber", "HSlider", UiIcons.knob(touch_scaled(30, 1.6), Color.WHITE, HOT))
	theme.set_icon("grabber_highlight", "HSlider", UiIcons.knob(touch_scaled(34, 1.6), Color.WHITE, HOT))

	# The *_mirrored icons are used right-to-left (settings rows put the switch before its description).
	for suffix: String in ["", "_disabled", "_mirrored", "_disabled_mirrored"]:
		theme.set_icon("checked" + suffix, "CheckButton", UiIcons.switch(true, touch_scaled(40)))
		theme.set_icon("unchecked" + suffix, "CheckButton", UiIcons.switch(false, touch_scaled(40)))
	var clear := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state, "CheckButton", clear)
	theme.set_color("font_color", "CheckButton", ACCENT)
	theme.set_color("font_hover_color", "CheckButton", Color.WHITE)
	theme.set_color("font_pressed_color", "CheckButton", ACCENT)
	theme.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	theme.set_font_size("font_size", "CheckButton", 24)
	theme.set_constant("h_separation", "CheckButton", 18)
	theme.set_constant("icon_max_width", "CheckButton", 0)
