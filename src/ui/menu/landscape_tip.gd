# Line near the top of the menu screens that suggests turning the phone sideways, shown only while the screen is
# portrait (it follows rotation in the menus). The main menu hides it behind the shop; home, song list and settings
# show it. Related: src/ui/menu/main_menu.gd, src/presentation/level/display_orientation.gd
class_name LandscapeTip
extends Label

const TEXT: String = "Turn your phone sideways for the best experience"
const COLOR: Color = Color(0.75, 0.9, 1.0)

## True while a screen that should not show the tip is open (the shop).
var suppressed: bool = false:
	set(value):
		suppressed = value
		_refresh()


func _ready() -> void:
	text = TEXT
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_left = 60.0
	offset_right = -60.0
	offset_top = 110.0
	offset_bottom = 200.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 32)
	add_theme_color_override("font_color", COLOR)
	get_viewport().size_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = not suppressed and is_inside_tree() and DisplayOrientation.is_portrait(get_viewport())
	if visible:
		# Below the notch / camera cutout: the safe area is in screen pixels, the label in canvas units.
		var window_height: float = maxf(get_window().size.y, 1.0)
		var safe_top: float = DisplayServer.get_display_safe_area().position.y 				* get_viewport().get_visible_rect().size.y / window_height
		offset_top = maxf(110.0, safe_top + 40.0)
		offset_bottom = offset_top + 90.0
