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


func test_every_cue_is_playable_on_its_beat() -> void:
	# The previous action has ended and the player is on the ground (unless the cue is a jump orb), so
	# autoplay never relies on the input buffer: a buffered cue would start late and look off-beat.
	var config: GameplayConfig = GameplayConfig.create_default()
	for file_name: String in DirAccess.get_files_at(MUSIC_DIRECTORY):
		if not file_name.ends_with(".chart.json"):
			continue
		var chart: LevelChart = ChartLoader.load_file(MUSIC_DIRECTORY.path_join(file_name), config)
		var simulation := RunSimulation.new(chart, config, ReferenceRun.START_BEAT)
		var late: PackedStringArray = []
		simulation.action_started.connect(func(action: ActionDefinition, start_beat: float, cue_index: int) -> void:
			if cue_index >= 0 and start_beat > chart.cues[cue_index].beat + 0.0001:
				late.append("%s cue %.2f started %.3f" % [action.id, chart.cues[cue_index].beat, start_beat]))
		Autoplay.new(chart, ReferenceRun.START_BEAT).drive(simulation, chart.end_beat + 1.0)
		assert_true(late.is_empty(), "%s: %s" % [file_name, ", ".join(late)])


func test_difficulty_ramps_up_toward_the_end() -> void:
	# Same weights as tools/audio/draft_chart.py (DIFFICULTY_WEIGHTS), scaled by run speed.
	var weights: Dictionary[int, float] = {
		ActionDefinition.Kind.JUMP: 1.0, ActionDefinition.Kind.DODGE: 1.25, ActionDefinition.Kind.FLIP: 1.75,
	}
	var config: GameplayConfig = GameplayConfig.create_default()
	for file_name: String in DirAccess.get_files_at(MUSIC_DIRECTORY):
		# Levels built from a recording follow the author's taps (possibly a partial recording), not a ramp.
		if not file_name.ends_with(".chart.json") or file_name.ends_with(".rec.chart.json"):
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
