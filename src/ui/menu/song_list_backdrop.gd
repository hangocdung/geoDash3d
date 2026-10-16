# Backdrop of the song list page: landscape, dark behind the list and clear over the menu demo (like the home page).
# Split out of song_list_panel.gd to keep that file under the 300-line limit. Related: src/ui/menu/song_list_panel.gd
class_name SongListBackdrop
extends RefCounted


## `list_share`: the list column's share of the width; `color`: the shade colour.
static func create(list_share: float, color: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.9))
	gradient.set_color(1, Color(color, 0.0))
	gradient.add_point(list_share, Color(color, 0.75))
	gradient.add_point(list_share + 0.12, Color(color, 0.1))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	var backdrop := TextureRect.new()
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return backdrop
