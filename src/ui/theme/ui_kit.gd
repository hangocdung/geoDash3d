# Builders for the shared UI pieces: icon buttons (with an optional chevron), screen headers (BACK + icon + title +
# subtitle), icons, difficulty badges and the safe-area margin. Screens compose these instead of styling by hand.
# Related: src/ui/theme/ui_theme.gd, src/ui/theme/ui_screen.gd, src/ui/theme/ui_dialog.gd
class_name UiKit
extends RefCounted

const ICON_SIZE: int = 34
const CHEVRON_SIZE: int = 26
const MIN_MARGIN: float = 48.0


## Button with a leading icon. `variation` is a UiTheme role ("PrimaryButton", "TabButton", …); `chevron` adds the
## trailing ">" and left-aligns the text (menu entries).
static func button(text: String, icon: StringName, variation: String = "", chevron: bool = false,
		size: Vector2 = Vector2(420, 72), sound_id: StringName = &"ui.tap") -> Button:
	var result: Button = UiTheme.make_button(text, size.x, size.y, sound_id)
	result.theme_type_variation = variation
	var icon_color: Color = Color.WHITE if variation == "PrimaryButton" else UiTheme.ACCENT
	if not icon.is_empty():
		result.icon = UiIcons.get_icon(icon, ICON_SIZE if size.y >= 64.0 else 26, icon_color)
		# Godot draws the icon at the button's edge: left-aligned text keeps it next to the icon.
		result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if chevron:
		var arrow: TextureRect = icon_rect(&"chevron", CHEVRON_SIZE, Color(icon_color, 0.9))
		arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		arrow.offset_left = -CHEVRON_SIZE - 24.0
		arrow.offset_right = -24.0
		arrow.offset_top = -CHEVRON_SIZE * 0.5
		arrow.offset_bottom = CHEVRON_SIZE * 0.5
		result.add_child(arrow)
	return result


static func icon_rect(name: StringName, pixel_size: int, color: Color = UiTheme.ACCENT) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = UiIcons.get_icon(name, pixel_size, color)
	rect.custom_minimum_size = Vector2(pixel_size, pixel_size)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func label(text: String, variation: String = "", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = variation
	result.horizontal_alignment = align
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## BACK button, then the screen icon, title and subtitle. `back` null leaves the button out.
static func header(title: String, subtitle: String, icon: StringName, back: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	if back.is_valid():
		var back_button: Button = button("BACK", &"back", "", false, Vector2(0, 64), &"ui.back")
		back_button.add_theme_font_size_override("font_size", 26)
		back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		back_button.pressed.connect(back)
		row.add_child(back_button)
	row.add_child(icon_rect(icon, 64, UiTheme.ACCENT))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -6)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	var title_label: Label = label(title, "HeaderTitle")
	title_label.add_theme_color_override("font_color", UiTheme.ACCENT)
	titles.add_child(title_label)
	if not subtitle.is_empty():
		titles.add_child(label(subtitle, "HeaderSubtitle"))
	return row


## Small coloured tag (difficulty).
static func badge(text: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Badge"
	panel.self_modulate = color
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_label: Label = label(text, "", HORIZONTAL_ALIGNMENT_CENTER)
	text_label.add_theme_font_size_override("font_size", 20)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.add_theme_constant_override("outline_size", 0)
	panel.add_child(text_label)
	return panel


## Canvas-unit margins that keep content off the edges and out of the notch / rounded corners.
static func safe_margins(control: Control) -> Vector4:
	var margins := Vector4(MIN_MARGIN, MIN_MARGIN * 0.75, MIN_MARGIN, MIN_MARGIN * 0.75)
	if not OS.has_feature("mobile") or not control.is_inside_tree():
		return margins
	var window: Window = control.get_window()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if window.size.x <= 0 or safe.size.x <= 0:
		return margins
	var canvas_per_pixel: float = control.get_viewport().get_visible_rect().size.x / float(window.size.x)
	margins.x = maxf(margins.x, safe.position.x * canvas_per_pixel + 16.0)
	margins.y = maxf(margins.y, safe.position.y * canvas_per_pixel + 12.0)
	margins.z = maxf(margins.z, (window.size.x - safe.end.x) * canvas_per_pixel + 16.0)
	margins.w = maxf(margins.w, (window.size.y - safe.end.y) * canvas_per_pixel + 12.0)
	# The menu's bottom banner (GD3-240) would cover a page's bottom buttons (the song list's PLAY).
	margins.w = maxf(margins.w, float(Ads.banner_height_pixels()) * canvas_per_pixel + 12.0)
	return margins


static func is_portrait(control: Control) -> bool:
	return control.is_inside_tree() and DisplayOrientation.is_portrait(control.get_viewport())
