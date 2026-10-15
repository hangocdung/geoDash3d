# Runs a complete deterministic autoplay for every staged package chart before publication.
# Related: publish_song.py, test_shipped_charts.gd.
extends SceneTree


func _initialize() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	var config: GameplayConfig = GameplayConfig.create_default()
	for path: String in paths:
		var chart: LevelChart = ChartLoader.load_file(path, config)
		if chart == null:
			quit(1)
			return
		var simulation: RunSimulation = Autoplay.run_full(chart, config, false)
		if simulation.is_dead or not simulation.is_completed or simulation.grade_counts[Judgement.Grade.MISS] != 0:
			push_error("Package autoplay failed: " + path)
			quit(1)
			return
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		print("PACKAGE_METADATA ", JSON.stringify({"chart": path.get_file(), "difficulty": ChartDifficulty.score(data)}))
	print("PACKAGE_AUTOPLAY_OK %d" % paths.size())
	quit(0)
