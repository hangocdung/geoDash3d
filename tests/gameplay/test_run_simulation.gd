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
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}, {"beat": 8, "type": "dodge_left"},
			{"beat": 12, "type": "dodge_right"}, {"beat": 16, "type": "flip"}], 120.0, 7.0, 24.0)
	var edge_beats: float = WINDOW_EDGE_SEC / chart.tempo.seconds_per_beat_at(0.0)
	for offset: float in [-edge_beats, edge_beats]:
		var taps: Array[float] = [4.0 + offset, 8.0 + offset, 12.0 + offset, 16.0 + offset]
		var simulation: RunSimulation = _simulate_taps(chart, taps, 22.0)
		assert_false(simulation.is_dead, "tap offset %.3f beats, died at %.2f" % [offset, simulation.current_beat])
		assert_eq(simulation.grade_counts[Judgement.Grade.GOOD], 4)


func test_window_edges_survive_at_high_speed() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}, {"beat": 8, "type": "dodge_right"}],
			120.0, 10.0, 12.0)
	var edge_beats: float = WINDOW_EDGE_SEC / chart.tempo.seconds_per_beat_at(0.0)
	for offset: float in [-edge_beats, edge_beats]:
		assert_false(_simulate_taps(chart, [4.0 + offset, 8.0 + offset], 12.0).is_dead, "offset %.3f" % offset)


func test_tap_far_too_early_uses_default_jump_and_dies() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}])
	var simulation: RunSimulation = _simulate_taps(chart, [3.4], 8.0)
	assert_true(simulation.is_dead)


func test_jump_into_wall_dies_but_dodge_passes() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "dodge_left"}])
	assert_true(_simulate_taps(chart, [3.5], 8.0).is_dead, "default jump cannot clear a wall")
	assert_true(_simulate_taps(chart, [], 8.0).is_dead, "standing still hits the wall")
	assert_false(_simulate_taps(chart, [4.0], 8.0).is_dead, "dodge into the gap")


func test_dodge_moves_toward_the_gap() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "dodge_left"}, {"beat": 8, "type": "dodge_right"}])
	var simulation: RunSimulation = _simulate_taps(chart, [4.0], 4.6)
	assert_almost_eq(simulation.player_offset_at(4.6).x, -1.0, 0.001, "left = negative lateral")
	simulation.advance_to(5.5)
	simulation.tap(8.0)
	assert_almost_eq(simulation.player_offset_at(8.6).x, 1.0, 0.001)


func test_flip_passes_under_gate_but_jump_does_not() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "flip"}])
	var flipped: RunSimulation = _simulate_taps(chart, [4.0], 8.0)
	assert_false(flipped.is_dead)
	assert_true(_simulate_taps(chart, [3.5], 8.0).is_dead, "default jump hits the gate")
	var config: GameplayConfig = GameplayConfig.create_default()
	var hanging: Vector2 = flipped.config.find_action(&"flip").offset_at(0.5)
	assert_almost_eq(hanging.y, -(config.track_thickness + GameplayConfig.CUBE_SIZE), 0.001, "under the track")
	assert_almost_eq(hanging.x, 0.0, 0.001, "centered under the track")


func test_buffered_tap_starts_next_action_on_landing() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}, {"beat": 5.5, "type": "jump"}])
	var late_then_early: Array[float] = [4.25, 5.22]
	var simulation: RunSimulation = _simulate_taps(chart, late_then_early, 10.0)
	assert_false(simulation.is_dead)
	assert_eq(simulation.grade_counts[Judgement.Grade.MISS], 0)


func test_result_is_independent_of_frame_rate() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}, {"beat": 6, "type": "dodge_right"},
			{"beat": 8, "type": "flip"}])
	var coarse := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var fine := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var taps: Array[float] = [4.27, 6.1, 8.2]
	for simulation: RunSimulation in [coarse, fine]:
		var frame_step: float = 0.37 if simulation == coarse else 0.011
		var beat: float = -1.0
		var tap_index: int = 0
		while beat < 12.0:
			beat += frame_step
			while tap_index < taps.size() and taps[tap_index] <= beat:
				simulation.tap(taps[tap_index])
				tap_index += 1
			simulation.advance_to(beat)
	assert_eq(coarse.is_dead, fine.is_dead)
	assert_eq(coarse.grade_counts, fine.grade_counts)


func test_invincible_run_records_hits_and_completes() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}, {"beat": 8, "type": "dodge_right"}],
			120.0, 7.0, 12.0)
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	simulation.invincible = true
	simulation.advance_to(13.0)
	assert_false(simulation.is_dead)
	assert_true(simulation.is_completed)
	assert_eq(simulation.hit_hazards.size(), 2)


func test_autoplay_passes_dense_chart() -> void:
	var events: Array[Dictionary] = []
	var beat: float = 4.0
	var types: Array[String] = ["jump", "dodge_left", "jump", "flip", "dodge_right", "jump"]
	var recovery: Dictionary[String, float] = {"jump": 1.5, "dodge_left": 1.75, "dodge_right": 1.75, "flip": 2.5}
	for index: int in 24:
		var action_type: String = types[index % types.size()]
		events.append({"beat": beat, "type": action_type})
		beat += recovery[action_type]
	var chart: LevelChart = ChartFixtures.make_chart(events, 120.0, 8.0, beat + 4.0)
	var simulation: RunSimulation = Autoplay.run_full(chart, GameplayConfig.create_default(), false)
	assert_false(simulation.is_dead, "died at beat %.3f" % simulation.current_beat)
	assert_true(simulation.is_completed)
	assert_eq(simulation.grade_counts[Judgement.Grade.PERFECT], 24)


func test_practice_checkpoints_restart_before_last_passed() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 17, "type": "jump"}, {"beat": 33, "type": "jump"}],
			120.0, 7.0, 48.0)
	var tracker := PracticeTracker.new(chart)
	tracker.begin(-4.0)
	assert_eq(tracker.checkpoints, PackedFloat64Array([16.0, 32.0]))
	assert_almost_eq(tracker.restart_beat(-4.0), -4.0, 0.0001, "no checkpoint yet")
	assert_false(tracker.update(16.2))
	assert_true(tracker.update(16.6))
	assert_almost_eq(tracker.restart_beat(-4.0), 14.0, 0.0001, "run-up before checkpoint 16")
	assert_true(tracker.update(40.0))
	# Run-up start 30 is safe (cue at 33 lies ahead with its spike).
	assert_almost_eq(tracker.restart_beat(-4.0), 30.0, 0.0001)
	assert_eq(tracker.reached_count(), 2)


func test_practice_ignores_checkpoints_before_the_start() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 33, "type": "jump"}], 120.0, 7.0, 48.0)
	var tracker := PracticeTracker.new(chart)
	tracker.begin(30.0)
	assert_false(tracker.update(31.0), "checkpoint 16 was not earned in this attempt")
	assert_almost_eq(tracker.restart_beat(30.0), 30.0, 0.0001)
	assert_true(tracker.update(33.0))
	tracker.begin(30.0)
	assert_false(tracker.update(33.0), "already earned")
	assert_eq(tracker.reached_count(), 2)
