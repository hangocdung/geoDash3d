extends TestCase

const WINDOW_EDGE_SEC: float = 0.14


func _simulate_taps(chart: LevelChart, tap_beats: Array[float], until_beat: float) -> RunSimulation:
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	for beat: float in tap_beats:
		simulation.tap(beat)
	simulation.advance_to(until_beat)
	return simulation


func test_no_tap_dies_on_spike() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}])
	var simulation: RunSimulation = _simulate_taps(chart, [], 8.0)
	assert_true(simulation.is_dead)
	assert_eq(simulation.grade_counts[Judgement.Grade.MISS], 1)


func test_perfect_jump_clears_spike() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}])
	var simulation: RunSimulation = _simulate_taps(chart, [4.0], 8.0)
	assert_false(simulation.is_dead)
	assert_eq(simulation.grade_counts[Judgement.Grade.PERFECT], 1)


func test_window_edges_still_survive() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}, {"beat": 8, "type": "dash"}])
	var edge_beats: float = WINDOW_EDGE_SEC / chart.tempo.seconds_per_beat_at(0.0)
	for offset: float in [-edge_beats, edge_beats]:
		var simulation: RunSimulation = _simulate_taps(chart, [4.0 + offset, 8.0 + offset], 12.0)
		assert_false(simulation.is_dead, "tap offset %.3f beats" % offset)
		assert_eq(simulation.grade_counts[Judgement.Grade.GOOD], 2)


func test_tap_far_too_early_uses_default_jump_and_dies() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}])
	var simulation: RunSimulation = _simulate_taps(chart, [3.4], 8.0)
	assert_true(simulation.is_dead)


func test_jump_into_barrier_dies_but_dash_passes() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "dash"}])
	var jumped := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	jumped.tap(3.5)  # outside the dash window: default jump
	jumped.advance_to(8.0)
	assert_true(jumped.is_dead)
	var dashed: RunSimulation = _simulate_taps(chart, [4.0], 8.0)
	assert_false(dashed.is_dead)


func test_buffered_tap_starts_next_action_on_landing() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}, {"beat": 5.5, "type": "jump"}])
	var late_then_early: Array[float] = [4.25, 5.22]
	var simulation: RunSimulation = _simulate_taps(chart, late_then_early, 10.0)
	assert_false(simulation.is_dead)
	assert_eq(simulation.grade_counts[Judgement.Grade.MISS], 0)


func test_result_is_independent_of_frame_rate() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}, {"beat": 6, "type": "dash"}])
	var coarse := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var fine := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var taps: Array[float] = [4.27, 6.1]
	for simulation: RunSimulation in [coarse, fine]:
		var frame_step: float = 0.37 if simulation == coarse else 0.011
		var beat: float = -1.0
		var tap_index: int = 0
		while beat < 10.0:
			beat += frame_step
			while tap_index < taps.size() and taps[tap_index] <= beat:
				simulation.tap(taps[tap_index])
				tap_index += 1
			simulation.advance_to(beat)
	assert_eq(coarse.is_dead, fine.is_dead)
	assert_eq(coarse.grade_counts, fine.grade_counts)


func test_invincible_run_records_hits_and_completes() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}, {"beat": 8, "type": "dash"}], 120.0, 7.0, 12.0)
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	simulation.invincible = true
	simulation.advance_to(13.0)
	assert_false(simulation.is_dead)
	assert_true(simulation.is_completed)
	assert_eq(simulation.hit_hazards.size(), 2)


func test_autoplay_passes_dense_chart() -> void:
	var events: Array[Dictionary] = []
	var beat: float = 4.0
	var types: Array[String] = ["jump", "jump", "dash", "jump", "dash", "dash"]
	for index: int in 24:
		events.append({"beat": beat, "type": types[index % types.size()]})
		beat += 1.5 if index % 3 != 2 else 1.0
	var chart: LevelChart = ChartFixtures.make_chart(events, 120.0, 7.0, beat + 4.0)
	var simulation: RunSimulation = Autoplay.run_full(chart, GameplayConfig.create_default(), false)
	assert_false(simulation.is_dead, "died at beat %.3f" % simulation.current_beat)
	assert_true(simulation.is_completed)
	assert_eq(simulation.grade_counts[Judgement.Grade.PERFECT], 24)
