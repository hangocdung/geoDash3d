# Overlay shown when the run is paused or complete: title/stats plus RESUME, RESTART and MENU; results also show the
# rank (S/A/B/C) and NEXT SONG when another song is open (GD3-251).
# Buttons never take keyboard focus, so Space keeps meaning "tap" in the level.
# Related: src/ui/hud/hud.gd, src/presentation/level/level_runner.gd
class_name RunMenu
extends Control

signal resume_pressed
signal restart_pressed
signal menu_pressed
signal next_pressed

const RANK_COLORS: Dictionary[String, Color] = {"S": Color(1.0, 0.85, 0.3), "A": Color(0.4, 1.0, 0.7),
		"B": Color(0.5, 0.8, 1.0), "C": Color(0.75, 0.75, 0.85)}

var _title: Label
var _resume_button: Button
var _next_button: Button
var _rank: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	_rank = UiTheme.make_label("", 132, Color.WHITE)
	column.add_child(_rank)
	_title = UiTheme.make_label("", 56, UiTheme.ACCENT)
	# Wraps on narrow (portrait) screens instead of running off the edges.
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(960, 0)
	column.add_child(_title)
	_next_button = _add_button(column, "NEXT SONG", next_pressed)
	_resume_button = _add_button(column, "RESUME", resume_pressed)
	_add_button(column, "RESTART", restart_pressed)
	_add_button(column, "MENU", menu_pressed)
	visible = false


func open(title: String, can_resume: bool) -> void:
	_title.text = title
	_title.add_theme_font_size_override("font_size", 56)
	_rank.visible = false
	_next_button.visible = false
	_resume_button.visible = can_resume
	visible = true


## Level complete: big rank, the stats, NEXT SONG when `has_next`.
func open_results(text: String, rank: String, has_next: bool) -> void:
	open(text, false)
	_title.add_theme_font_size_override("font_size", 44)
	_rank.text = rank
	_rank.add_theme_color_override("font_color", RANK_COLORS.get(rank, Color.WHITE))
	_rank.visible = true
	_next_button.visible = has_next


func close() -> void:
	visible = false


func _add_button(parent: Control, text: String, emitted: Signal) -> Button:
	var button: Button = UiTheme.make_button(text, 360.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: emitted.emit())
	parent.add_child(button)
	return button
