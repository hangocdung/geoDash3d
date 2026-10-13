# Scene paths and navigation helpers shared by menus and the level.
# Related: src/ui/menu/main_menu.gd, src/presentation/level/level_runner.gd
class_name Scenes
extends RefCounted

const MAIN_MENU: String = "res://src/ui/menu/main_menu.tscn"
const LEVEL: String = "res://src/presentation/level/level.tscn"
const CALIBRATION: String = "res://src/ui/calibration/calibration_screen.tscn"
const METRONOME: String = "res://src/authoring/metronome/metronome.tscn"
const DEFAULT_CHART: String = "res://assets/music/the_dawn_assembly.chart.json"


static func go_to(tree: SceneTree, scene_path: String) -> void:
	var error: Error = tree.change_scene_to_file(scene_path)
	if error != OK:
		push_error("Scenes: cannot open '%s' (%s)" % [scene_path, error_string(error)])
