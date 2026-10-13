# Overlay shown when the run is paused or complete: title/stats plus RESUME, RESTART and MENU.
# Buttons never take keyboard focus, so Space keeps meaning "tap" in the level.
# Related: src/ui/hud/hud.gd, src/presentation/level/level_runner.gd
class_name RunMenu
extends Control

signal resume_pressed
signal restart_pressed
signal menu_pressed

var _title: Label
var _resume_button: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_title = UiTheme.make_label("", 56, UiTheme.ACCENT)
	column.add_child(_title)
	_resume_button = _add_button(column, "RESUME", resume_pressed)
	_add_button(column, "RESTART", restart_pressed)
	_add_button(column, "MENU", menu_pressed)
	visible = false


func open(title: String, can_resume: bool) -> void:
	_title.text = title
	_resume_button.visible = can_resume
	visible = true


func close() -> void:
	visible = false


func _add_button(parent: Control, text: String, emitted: Signal) -> Button:
	var button: Button = UiTheme.make_button(text, 360.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: emitted.emit())
	parent.add_child(button)
	return button
