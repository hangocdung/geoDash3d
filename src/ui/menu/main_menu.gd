# Title screen: the level runs in attract mode (autoplay, no HUD) behind the menu.
# If level arguments were passed on the command line (--autoplay, --capture, …) it jumps straight
# into the level so tooling keeps working. Related: src/ui/scenes.gd, src/presentation/level/level_runner.gd
class_name MainMenu
extends Node

const LEVEL_SCENE: PackedScene = preload("res://src/presentation/level/level.tscn")
const PRACTICE_RATES: Array[float] = [1.0, 0.75, 0.5]

var _menu_column: VBoxContainer
var _settings_button: Button
var _settings: SettingsPanel
var _practice_panel: PanelContainer
var _practice_button: Button
var _root: Control


func _ready() -> void:
	if LaunchOptions.has_level_arguments():
		Scenes.go_to.call_deferred(get_tree(), Scenes.LEVEL)
		return
	var level: LevelRunner = LEVEL_SCENE.instantiate() as LevelRunner
	level.preset_options = LaunchOptions.attract()
	add_child(level)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_root)
	_build_backdrop()
	_build_menu()


func _build_backdrop() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)


func _build_menu() -> void:
	_menu_column = VBoxContainer.new()
	_menu_column.set_anchors_preset(Control.PRESET_CENTER)
	_menu_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_column.add_theme_constant_override("separation", 12)
	_root.add_child(_menu_column)
	var title: Label = UiTheme.make_label("GEODASH 3D", 104, UiTheme.ACCENT)
	title.add_theme_color_override("font_outline_color", UiTheme.HOT)
	title.add_theme_constant_override("outline_size", 6)
	_menu_column.add_child(title)
	_menu_column.add_child(UiTheme.make_label("THE DAWN ASSEMBLY", 34, UiTheme.HOT))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_menu_column.add_child(spacer)
	var play: Button = _add_button("PLAY", func() -> void: Scenes.go_to(get_tree(), Scenes.LEVEL))
	_practice_button = _add_button("PRACTICE", _open_practice)
	_add_button("CALIBRATE AUDIO", func() -> void: Scenes.go_to(get_tree(), Scenes.CALIBRATION))
	_add_button("SYNC TEST", func() -> void: Scenes.go_to(get_tree(), Scenes.METRONOME))
	_settings_button = _add_button("SETTINGS", _open_settings)
	if OS.is_debug_build():
		_add_button("RECORD (DEV)", func() -> void: Scenes.go_to(get_tree(), Scenes.RECORDER))
	if not OS.has_feature("mobile"):
		_add_button("QUIT", func() -> void: get_tree().quit())
	play.grab_focus()


func _add_button(text: String, action: Callable) -> Button:
	var button: Button = UiTheme.make_button(text, 420.0, 62.0)
	button.pressed.connect(action)
	_menu_column.add_child(button)
	return button


func _open_settings() -> void:
	_menu_column.visible = false
	_settings = SettingsPanel.new()
	_settings.set_anchors_preset(Control.PRESET_CENTER)
	_settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settings.closed.connect(_close_settings)
	_root.add_child(_settings)


func _close_settings() -> void:
	_settings.queue_free()
	_settings = null
	_menu_column.visible = true
	_settings_button.grab_focus()


func _open_practice() -> void:
	_menu_column.visible = false
	_practice_panel = PanelContainer.new()
	_practice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_practice_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_practice_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_practice_panel.add_child(column)
	column.add_child(UiTheme.make_label("PRACTICE", 48, UiTheme.ACCENT))
	column.add_child(UiTheme.make_label("Checkpoints every 16 beats.
Dying restarts from the last one.", 26))
	var first: Button = null
	for rate: float in PRACTICE_RATES:
		var button: Button = UiTheme.make_button("SPEED %d%%" % roundi(rate * 100.0), 360.0)
		button.pressed.connect(func() -> void:
			LaunchOptions.set_next_run(LaunchOptions.practice_run(rate))
			Scenes.go_to(get_tree(), Scenes.LEVEL))
		column.add_child(button)
		if first == null:
			first = button
	var back: Button = UiTheme.make_button("BACK", 360.0)
	back.pressed.connect(_close_practice)
	column.add_child(back)
	_root.add_child(_practice_panel)
	first.grab_focus()


func _close_practice() -> void:
	_practice_panel.queue_free()
	_practice_panel = null
	_menu_column.visible = true
	_practice_button.grab_focus()
