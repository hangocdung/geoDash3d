# Dev check of touch scrolling on the song list (TouchScroll): swipes a row (the list scrolls, the selection stays),
# lets the fling run, then taps a row (it is selected). Prints SWIPE / MOMENTUM / TAP lines.
# Usage: godot --path . -s res://tools/capture/touch_scroll_check.gd -- --touch-ui   Related: src/ui/theme/touch_scroll.gd
extends SceneTree
var frame: int = 0
var panel: Control
var scroll: ScrollContainer
var start_scroll: int = 0
var start_selected: String = ""
var y: float = 0.0
var x: float = 0.0

func _initialize() -> void:
	change_scene_to_file("res://tools/capture/previews/song_list_preview.tscn")

func _mouse(pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(e)

func _move(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 20:
		panel = root.find_children("*", "SongListPanel", true, false)[0] as Control
		scroll = panel.find_children("*", "TouchScroll", true, false)[0] as ScrollContainer
		var rows: Array[Node] = scroll.find_children("*", "Button", true, false)
		var row: Control = rows[2] as Control
		var r: Rect2 = row.get_global_rect()
		# Viewport coords: canvas -> window via the canvas transform.
		var center: Vector2 = root.get_final_transform() * (r.position + r.size * 0.5)
		x = center.x; y = center.y
		start_scroll = scroll.scroll_vertical
		start_selected = panel.get("selected_path")
		print("rows=", rows.size(), " max=", scroll.get_v_scroll_bar().max_value, " page=", scroll.get_v_scroll_bar().page, " row filter=", row.mouse_filter)
		_mouse(true, Vector2(x, y))
	elif frame > 20 and frame <= 32:
		y -= 25.0
		_move(Vector2(x, y), Vector2(0, -25))
	elif frame == 33:
		_mouse(false, Vector2(x, y))
	elif frame == 34:
		print("SWIPE scroll ", start_scroll, " -> ", scroll.scroll_vertical, " selected same=", panel.get("selected_path") == start_selected)
	elif frame == 70:
		print("AFTER MOMENTUM scroll=", scroll.scroll_vertical)
		scroll.scroll_vertical = 0
	elif frame == 72:
		var rows: Array[Node] = scroll.find_children("*", "Button", true, false)
		var target: Control = null
		for n: Node in rows:
			var b: Button = n as Button
			if b.toggle_mode and not b.button_pressed and b.get_global_rect().intersects(scroll.get_global_rect()):
				target = b
				break
		var r: Rect2 = target.get_global_rect()
		var c: Vector2 = root.get_final_transform() * (r.position + r.size * 0.5)
		x = c.x; y = c.y
		start_selected = panel.get("selected_path")
		_mouse(true, Vector2(x, y))
	elif frame == 74:
		_mouse(false, Vector2(x, y))
	elif frame == 76:
		print("TAP selected changed=", panel.get("selected_path") != start_selected)
		quit()
	return false
