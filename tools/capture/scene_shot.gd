# Screenshot any scene after it has run for a number of frames (menus, calibration, tools).
# Usage: godot --path . -s res://tools/capture/scene_shot.gd -- --scene=res://… --frames=90 --out=res://tools/capture/out/x.png
# Related: src/presentation/level/capture_controller.gd (level captures at song times)
extends SceneTree

var _frames_left: int = 90
var _out_path: String = "res://tools/capture/out/scene.png"


func _initialize() -> void:
	var scene_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
		elif argument.begins_with("--frames="):
			_frames_left = argument.trim_prefix("--frames=").to_int()
		elif argument.begins_with("--out="):
			_out_path = argument.trim_prefix("--out=")
	AudioServer.set_bus_mute(0, true)
	# UI canvas matching the window shape (portrait windows get the 1080x1920 canvas, as in the game).
	DisplayOrientation.setup(root)
	var error: Error = change_scene_to_file(scene_path)
	if error != OK:
		push_error("scene_shot: cannot open '%s' (%s)" % [scene_path, error_string(error)])
		quit(1)


func _process(_delta: float) -> bool:
	_frames_left -= 1
	if _frames_left == 0:
		_save.call_deferred()
	return false


func _save() -> void:
	await RenderingServer.frame_post_draw
	var absolute: String = ProjectSettings.globalize_path(_out_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error: Error = root.get_viewport().get_texture().get_image().save_png(absolute)
	if error != OK:
		push_error("scene_shot: cannot save '%s' (%s)" % [absolute, error_string(error)])
		quit(1)
		return
	print("SHOT %s" % absolute)
	quit(0)
