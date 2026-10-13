# Shared neon UI theme (buttons, labels, sliders) built in code so every screen looks consistent.
# Related: src/ui/menu/main_menu.gd, src/ui/calibration/calibration_screen.gd, src/ui/hud/hud.gd
class_name UiTheme
extends RefCounted

const TEXT: Color = Color(0.86, 0.95, 1.0)
const ACCENT: Color = Color(0.3, 0.9, 1.0)
const HOT: Color = Color(1.0, 0.3, 0.85)
const PANEL: Color = Color(0.04, 0.02, 0.1, 0.82)

static var _cached: Theme


static func get_theme() -> Theme:
	if _cached != null:
		return _cached
	var theme := Theme.new()
	theme.default_font_size = 30
	theme.set_stylebox("normal", "Button", _box(PANEL, ACCENT, 2))
	theme.set_stylebox("hover", "Button", _box(Color(0.1, 0.05, 0.2, 0.9), HOT, 3))
	theme.set_stylebox("pressed", "Button", _box(Color(0.2, 0.08, 0.3, 0.95), HOT, 3))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color.WHITE, 2))
	theme.set_stylebox("disabled", "Button", _box(PANEL, Color(0.3, 0.3, 0.4), 2))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_outline_color", "Label", Color(0.03, 0.0, 0.08, 0.9))
	theme.set_constant("outline_size", "Label", 8)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, Color(0.45, 0.35, 1.0, 0.8), 2))
	theme.set_stylebox("normal", "OptionButton", _box(PANEL, ACCENT, 2))
	theme.set_stylebox("hover", "OptionButton", _box(Color(0.1, 0.05, 0.2, 0.9), HOT, 3))
	theme.set_stylebox("pressed", "OptionButton", _box(Color(0.2, 0.08, 0.3, 0.95), HOT, 3))
	theme.set_stylebox("focus", "OptionButton", _box(Color(0, 0, 0, 0), Color.WHITE, 2))
	theme.set_color("font_color", "OptionButton", TEXT)
	var slider_track: StyleBoxFlat = _box(Color(0.1, 0.06, 0.2), Color(0.3, 0.3, 0.5), 1)
	slider_track.content_margin_top = 6
	slider_track.content_margin_bottom = 6
	theme.set_stylebox("slider", "HSlider", slider_track)
	var fill: StyleBoxFlat = _box(ACCENT * Color(1, 1, 1, 0.8), ACCENT, 1)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	_cached = theme
	return theme


static func make_button(text: String, minimum_width: float = 420.0, height: float = 72.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(minimum_width, height)
	return button


static func make_label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func _box(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(12)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box
