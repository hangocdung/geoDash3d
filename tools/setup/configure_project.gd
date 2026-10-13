# Headless setup script: writes settings that are awkward to hand-edit in project.godot
# (input map objects, autoloads). Idempotent; run after changing the values below.
# Usage: godot --headless --path . -s res://tools/setup/configure_project.gd
extends SceneTree

const ALL_DEVICES: int = -1
const TAP_KEYS: Array[Key] = [KEY_SPACE, KEY_UP, KEY_W]

const AUTOLOADS: Dictionary[String, String] = {
	"UserSettings": "*res://src/core/user_settings.gd",
	"Sfx": "*res://src/core/audio/sfx.gd",
}

const MAIN_SCENE: String = "res://src/ui/menu/main_menu.tscn"

## Global shader uniforms (`global uniform float beat_pulse;`), set at runtime by EnvironmentDirector.
const SHADER_GLOBALS: Dictionary[String, float] = {
	"beat_pulse": 0.0,
}


func _init() -> void:
	_configure_input()
	_configure_autoloads()
	_configure_shader_globals()
	ProjectSettings.set_setting("application/run/main_scene", MAIN_SCENE)
	var error: Error = ProjectSettings.save()
	if error != OK:
		push_error("configure_project: ProjectSettings.save() failed with %s" % error_string(error))
		quit(1)
		return
	print("configure_project: OK")
	quit(0)


func _configure_input() -> void:
	var events: Array[InputEvent] = []
	for keycode: Key in TAP_KEYS:
		var key_event := InputEventKey.new()
		key_event.device = ALL_DEVICES
		key_event.physical_keycode = keycode
		events.append(key_event)
	# Touch is delivered as emulated left mouse button (emulate_mouse_from_touch = true),
	# so mapping the mouse button covers both desktop and mobile without double triggers.
	var mouse_event := InputEventMouseButton.new()
	mouse_event.device = ALL_DEVICES
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	events.append(mouse_event)
	ProjectSettings.set_setting("input/tap", {"deadzone": 0.2, "events": events})

	var pause_event := InputEventKey.new()
	pause_event.device = ALL_DEVICES
	pause_event.physical_keycode = KEY_ESCAPE
	ProjectSettings.set_setting("input/pause", {"deadzone": 0.2, "events": [pause_event]})

	var restart_event := InputEventKey.new()
	restart_event.device = ALL_DEVICES
	restart_event.physical_keycode = KEY_R
	ProjectSettings.set_setting("input/restart", {"deadzone": 0.2, "events": [restart_event]})


func _configure_autoloads() -> void:
	for autoload_name: String in AUTOLOADS:
		ProjectSettings.set_setting("autoload/%s" % autoload_name, AUTOLOADS[autoload_name])


func _configure_shader_globals() -> void:
	for parameter_name: String in SHADER_GLOBALS:
		ProjectSettings.set_setting("shader_globals/%s" % parameter_name,
				{"type": "float", "value": SHADER_GLOBALS[parameter_name]})
