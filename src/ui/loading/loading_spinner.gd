# A spinning neon arc (loading indicator), drawn in code. It keeps turning while the main thread is free, i.e.
# while LevelLoader works on its thread. Related: src/ui/loading/loading_cover.gd, src/ui/menu/song_detail_card.gd
class_name LoadingSpinner
extends Control

const TURN_SEC: float = 0.9
const ARC_SPAN: float = TAU * 0.7

var color: Color = UiTheme.ACCENT
var line_width: float = 6.0
var _angle: float = 0.0


func _init(diameter: float = 64.0) -> void:
	custom_minimum_size = Vector2.ONE * diameter
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_angle = fmod(_angle + delta * TAU / TURN_SEC, TAU)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - line_width
	draw_arc(center, radius, 0.0, TAU, 48, Color(color, 0.15), line_width, true)
	draw_arc(center, radius, _angle, _angle + ARC_SPAN, 48, color, line_width, true)
