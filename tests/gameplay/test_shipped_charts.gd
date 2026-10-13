extends TestCase

const MUSIC_DIRECTORY: String = "res://assets/music"


func test_every_chart_loads_and_autoplay_clears_it() -> void:
	var chart_count: int = 0
	for file_name: String in DirAccess.get_files_at(MUSIC_DIRECTORY):
		if not file_name.ends_with(".chart.json"):
			continue
		chart_count += 1
		var config: GameplayConfig = GameplayConfig.create_default()
		var chart: LevelChart = ChartLoader.load_file(MUSIC_DIRECTORY.path_join(file_name), config)
		assert_not_null(chart, file_name)
		if chart == null:
			continue
		var simulation: RunSimulation = Autoplay.run_full(chart, config, false)
		assert_false(simulation.is_dead, "%s: autoplay died at beat %.3f" % [file_name, simulation.current_beat])
		assert_true(simulation.is_completed, "%s: run did not complete" % file_name)
		assert_eq(simulation.grade_counts[Judgement.Grade.MISS], 0, file_name)
		assert_true(ResourceLoader.exists(chart.song_path), "%s: missing song %s" % [file_name, chart.song_path])
	assert_true(chart_count > 0, "no charts found")


func test_no_action_is_unreachable_after_a_previous_one() -> void:
	# A cue must start after the previous action ends (allowing the input buffer), or it can't be hit.
	var config: GameplayConfig = GameplayConfig.create_default()
	for file_name: String in DirAccess.get_files_at(MUSIC_DIRECTORY):
		if not file_name.ends_with(".chart.json"):
			continue
		var chart: LevelChart = ChartLoader.load_file(MUSIC_DIRECTORY.path_join(file_name), config)
		for index: int in range(1, chart.cues.size()):
			var previous: ChartItems.ActionCue = chart.cues[index - 1]
			var gap: float = chart.cues[index].beat - previous.beat
			assert_true(gap >= previous.action.duration_beats,
					"%s: cue at beat %.2f follows %s at %.2f too closely" % [file_name, chart.cues[index].beat,
					previous.action.id, previous.beat])


func test_difficulty_ramps_up_toward_the_end() -> void:
	# Same weights as tools/audio/draft_chart.py (DIFFICULTY_WEIGHTS), scaled by run speed.
	var weights: Dictionary[int, float] = {
		ActionDefinition.Kind.JUMP: 1.0, ActionDefinition.Kind.DODGE: 1.25, ActionDefinition.Kind.FLIP: 1.75,
	}
	var config: GameplayConfig = GameplayConfig.create_default()
	for file_name: String in DirAccess.get_files_at(MUSIC_DIRECTORY):
		if not file_name.ends_with(".chart.json"):
			continue
		var chart: LevelChart = ChartLoader.load_file(MUSIC_DIRECTORY.path_join(file_name), config)
		var quarter: float = chart.end_beat / 4.0
		var first: float = 0.0
		var last: float = 0.0
		var previous_speed: float = 0.0
		for cue: ChartItems.ActionCue in chart.cues:
			var speed: float = chart.distance_map.rate_at(cue.beat)
			assert_true(speed >= previous_speed, "%s: speed drops at beat %.1f" % [file_name, cue.beat])
			previous_speed = speed
			var score: float = weights[cue.action.kind] * speed
			if cue.beat < quarter:
				first += score
			elif cue.beat >= chart.end_beat - quarter:
				last += score
		assert_true(last > first * 1.5, "%s: last quarter %.1f should be much harder than first %.1f" % [file_name,
				last, first])
