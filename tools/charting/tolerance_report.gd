# Prints how early and how late each cue can be tapped (every other cue perfect) while the run survives.
# Usage: "$GODOT" --headless --path . -s res://tools/charting/tolerance_report.gd -- --chart=res://... [--max-ms=150]
# Related: src/gameplay/simulation/run_simulation.gd, tools/charting/terrain_demo.py
extends SceneTree

const STEP_MS: int = 10
## Beats simulated after the tested cue (long enough for its landing and the next few cues).
const AFTER_BEATS: float = 6.0
const RUN_UP_BEATS: float = 2.0


func _initialize() -> void:
	var chart_path: String = Scenes.DEFAULT_CHART
	var max_ms: int = 150
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--chart="):
			chart_path = argument.get_slice("=", 1)
		elif argument.begins_with("--max-ms="):
			max_ms = argument.get_slice("=", 1).to_int()
	var config: GameplayConfig = GameplayConfig.create_default()
	var chart: LevelChart = ChartLoader.load_file(chart_path, config)
	if chart == null:
		push_error("tolerance_report: cannot load '%s'" % chart_path)
		quit(1)
		return
	var worst_ms: int = max_ms
	var worst_beat: float = NAN
	for index: int in chart.cues.size():
		var early_ms: int = _tolerance_ms(chart, config, index, -1, max_ms)
		var late_ms: int = _tolerance_ms(chart, config, index, 1, max_ms)
		print("%8.2f  %-11s  -%3d ms  +%3d ms" % [chart.cues[index].beat, chart.cues[index].action.id, early_ms,
				late_ms])
		if mini(early_ms, late_ms) < worst_ms:
			worst_ms = mini(early_ms, late_ms)
			worst_beat = chart.cues[index].beat
	print("TOLERANCE cues=%d worst=%d ms at beat %.2f" % [chart.cues.size(), worst_ms, worst_beat])
	quit()


func _tolerance_ms(chart: LevelChart, config: GameplayConfig, index: int, direction: int, max_ms: int) -> int:
	var survived_ms: int = 0
	for offset_ms: int in range(STEP_MS, max_ms + 1, STEP_MS):
		if not _survives(chart, config, index, float(direction * offset_ms) / 1000.0):
			break
		survived_ms = offset_ms
	return survived_ms


func _survives(chart: LevelChart, config: GameplayConfig, index: int, offset_sec: float) -> bool:
	var cue_beat: float = chart.cues[index].beat
	var start_beat: float = chart.safe_start_beat(cue_beat - RUN_UP_BEATS)
	var end_beat: float = minf(cue_beat + AFTER_BEATS, chart.end_beat + 1.0)
	var simulation := RunSimulation.new(chart, config, start_beat)
	var offset_beats: float = offset_sec / chart.tempo.seconds_per_beat_at(cue_beat)
	var taps: Array[float] = []
	for other: int in chart.cues.size():
		var beat: float = chart.cues[other].beat
		if beat >= start_beat and beat <= end_beat:
			taps.append(beat + (offset_beats if other == index else 0.0))
	taps.sort()
	for beat: float in taps:
		simulation.tap(beat)
	simulation.advance_to(end_beat)
	return not simulation.is_dead
