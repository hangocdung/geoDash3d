# Headless setup script: writes settings that are awkward to hand-edit in project.godot
# (input map objects, autoloads). Idempotent; run after changing the values below.
# Usage: godot --headless --path . -s res://tools/setup/configure_project.gd
extends SceneTree

const ALL_DEVICES: int = -1
const TAP_KEYS: Array[Key] = [KEY_SPACE, KEY_UP, KEY_W]

const AUTOLOADS: Dictionary[String, String] = {
	"UserSettings": "*res://src/core/user_settings.gd",
	"Sfx": "*res://src/core/audio/sfx.gd",
	"PerfProbe": "*res://src/core/perf_probe.gd",
}

const MAIN_SCENE: String = "res://src/ui/menu/main_menu.tscn"
## Editor plugins (export-time only): the Firebase Android plugin (GD3-230).
const EDITOR_PLUGINS: PackedStringArray = ["res://addons/geodash_firebase/plugin.cfg"]
## Phones start in any orientation; DisplayOrientation locks it while a level runs (GD3-210).
const HANDHELD_ORIENTATION: DisplayServer.ScreenOrientation = DisplayServer.SCREEN_SENSOR

## Import defaults for new images: the 3D detail textures (assets/textures) need mipmaps and VRAM compression
## (ETC2/ASTC on phones). Change a single 2D/UI image in the editor's Import dock if it should stay lossless.
const TEXTURE_IMPORT_DEFAULTS: Dictionary[String, Variant] = {
	"compress/mode": 2,
	"mipmaps/generate": true,
	"detect_3d/compress_to": 0,
}

## Global shader uniforms (`global uniform float beat_pulse;`), set at runtime by EnvironmentDirector.
## A Vector3 value declares a vec3 global, a Vector4 a vec4, anything else a float. A Color declares a vec4
## holding the linear color: the shaders get the same values as `source_color` uniforms (EnvironmentDirector
## converts the same way). The `pal_*` phase palette defaults are the `indigo` palette (PaletteLibrary.DEFAULT).
const SHADER_GLOBALS: Dictionary[String, Variant] = {
	"beat_pulse": 0.0,
	"soft_glow": 0.0,
	"run_beat": 0.0,
	"player_distance": 0.0,
	"player_position": Vector3.ZERO,
	"song_seconds": 0.0,
	"pal_sky_zenith": Color(0.02, 0.01, 0.07),
	"pal_sky_mid": Color(0.12, 0.04, 0.28),
	"pal_sky_horizon": Color(0.55, 0.16, 0.6),
	"pal_sky_accent": Color(0.35, 0.45, 1.0),
	"pal_sky_style": Vector4(1.0, 0.0, 1.0, 1.0),
	"pal_track_base": Color(0.03, 0.025, 0.07),
	"pal_track_grid": Color(0.25, 0.85, 1.0),
	"pal_track_rail": Color(0.3, 0.95, 1.0),
	"pal_track_streak": Color(0.75, 0.97, 1.0),
	"pal_block_base": Color(0.05, 0.045, 0.12),
	"pal_block_rail": Color(0.45, 0.75, 1.0),
	"pal_scenery_a": Color(0.25, 0.75, 1.0),
	"pal_scenery_b": Color(0.55, 0.4, 0.98),
	"pal_pillar": Color(0.55, 0.35, 1.0),
	"pal_decor_glow": Color(0.45, 0.4, 1.0),
	"pal_decor_accent": Color(0.3, 0.9, 1.0),
	# 1 = shaders sample the packed detail textures (MEDIUM/HIGH), 0 = flat neon look (LOW).
	"detail_textures": 1.0,
}


func _init() -> void:
	_configure_input()
	_configure_autoloads()
	_configure_shader_globals()
	ProjectSettings.set_setting("application/run/main_scene", MAIN_SCENE)
	ProjectSettings.set_setting("editor_plugins/enabled", EDITOR_PLUGINS)
	ProjectSettings.set_setting("display/window/handheld/orientation", HANDHELD_ORIENTATION)
	ProjectSettings.set_setting("importer_defaults/texture", TEXTURE_IMPORT_DEFAULTS)
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
		var value: Variant = SHADER_GLOBALS[parameter_name]
		var type_name: String = "float"
		if value is Color:
			var linear: Color = (value as Color).srgb_to_linear()
			value = Vector4(linear.r, linear.g, linear.b, linear.a)
		if value is Vector3:
			type_name = "vec3"
		elif value is Vector4:
			type_name = "vec4"
		ProjectSettings.set_setting("shader_globals/%s" % parameter_name, {"type": type_name, "value": value})
