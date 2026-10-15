# Loads one chart and lets autoplay play it through (the same check as tests/gameplay/test_shipped_charts.gd, for one
# file). Prints "CHECK ok cues=N" or "CHECK fail <reason>" and exits 1 on failure; used by tools/charting/auto_level.py.
# Usage: "$GODOT" --headless --path . -s res://tools/charting/check_chart.gd -- --chart=res://assets/music/<id>.chart.json
extends SceneTree


func _initialize() -> void:
	var chart_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--chart="):
			chart_path = argument.get_slice("=", 1)
	if chart_path.is_empty():
		push_error("check_chart: pass --chart=res://...")
		quit(1)
		return
	var config: GameplayConfig = GameplayConfig.create_default()
	var chart: LevelChart = ChartLoader.load_file(chart_path, config)
	if chart == null:
		print("CHECK fail cannot load %s" % chart_path)
		quit(1)
		return
	var simulation: RunSimulation = Autoplay.run_full(chart, config, false)
	if simulation.is_dead:
		print("CHECK fail autoplay died at beat %.3f" % simulation.current_beat)
		quit(1)
		return
	if not simulation.is_completed or simulation.grade_counts[Judgement.Grade.MISS] > 0:
		print("CHECK fail run incomplete or missed cues (%d)" % simulation.grade_counts[Judgement.Grade.MISS])
		quit(1)
		return
	print("CHECK ok cues=%d end_beat=%.1f" % [chart.cues.size(), chart.end_beat])
	quit()
