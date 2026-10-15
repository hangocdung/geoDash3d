# Underside runs (GD3-112): flip_down takes the player under the track, plain jumps clear hazards hanging
# there, flip_up brings it back; the loader checks the run, shields put the player back on the run's side.
# Related: src/gameplay/simulation/action_state.gd, src/gameplay/chart/level_chart.gd, chart_loader.gd
extends TestCase


func _run_chart() -> LevelChart:
	return ChartFixtures.make_chart([{"beat": 4, "type": "flip_down"}, {"beat": 6, "type": "jump"},
			{"beat": 8, "type": "jump"}, {"beat": 10, "type": "flip_up"}], 120.0, 7.0, 16.0)


func _simulate_taps(chart: LevelChart, tap_beats: Array[float], until_beat: float,
		invincible: bool = false) -> RunSimulation:
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	simulation.invincible = invincible
	for beat: float in tap_beats:
		simulation.tap(beat)
	simulation.advance_to(until_beat)
	return simulation


func test_flip_parts_meet_under_the_track() -> void:
	var config: GameplayConfig = GameplayConfig.create_default()
	var down: ActionDefinition = config.find_action(&"flip_down")
	var up: ActionDefinition = config.find_action(&"flip_up")
	assert_almost_eq(down.offset_at(0.0).y, 0.0, 0.001, "flip_down starts on the road")
	assert_almost_eq(down.offset_at(1.0).y, -config.underside_depth(), 0.001, "and ends under it")
	assert_almost_eq(up.offset_at(0.0).y, -config.underside_depth(), 0.001, "flip_up starts under the road")
	assert_almost_eq(up.offset_at(1.0).length(), 0.0, 0.001, "and ends on it")
	assert_true(down.offset_at(0.5).x > 0.0 and up.offset_at(0.5).x < 0.0, "over one edge, back up the other")


func test_loader_marks_run_and_hazard_faces() -> void:
	var chart: LevelChart = _run_chart()
	assert_eq(chart.underside_ranges.size(), 1)
	assert_almost_eq(chart.underside_ranges[0].x, 5.0, 0.0001, "under once flip_down ends")
	assert_almost_eq(chart.underside_ranges[0].y, 10.0, 0.0001, "until flip_up starts")
	var faces: Dictionary[float, bool] = {}
	for placement: ChartItems.HazardPlacement in chart.hazards:
		faces[placement.beat] = placement.underside
	assert_false(faces[5.25], "flip_down's gate stays on the road")
	assert_true(faces[6.5] and faces[8.5], "spikes of the run hang under the track")
	assert_true(faces[11.25], "flip_up's gate hangs under the track")
	assert_true(chart.is_cue_underside(chart.cues[3]), "flip_up is tapped from under the track")
	assert_false(chart.is_cue_underside(chart.cues[0]))


func test_perfect_run_goes_under_and_back() -> void:
	var chart: LevelChart = _run_chart()
	var config: GameplayConfig = GameplayConfig.create_default()
	var simulation := RunSimulation.new(chart, config, -1.0)
	simulation.tap(4.0)
	simulation.advance_to(5.5)
	assert_true(simulation.is_underside())
	assert_almost_eq(simulation.player_offset_at(5.5).y, -config.underside_depth(), 0.001)
	simulation.tap(6.0)
	simulation.advance_to(6.5)
	assert_almost_eq(simulation.player_offset_at(6.5).y, -config.underside_depth() - 2.0, 0.01,
			"jumps go away from the underside")
	simulation.tap(8.0)
	simulation.tap(10.0)
	simulation.advance_to(10.5)
	assert_false(simulation.is_underside(), "flip_up starts the way back")
	simulation.advance_to(16.0)
	assert_false(simulation.is_dead, "died at %.2f" % simulation.current_beat)
	assert_almost_eq(simulation.player_offset_at(12.0).y, 0.0, 0.001, "back on the road")
	assert_eq(simulation.grade_counts[Judgement.Grade.PERFECT], 4)


func test_each_missed_tap_dies_where_expected() -> void:
	var chart: LevelChart = _run_chart()
	var no_flip_down: RunSimulation = _simulate_taps(chart, [6.0, 8.0, 10.0], 16.0)
	assert_true(no_flip_down.is_dead and no_flip_down.current_beat < 5.5, "gate on the road")
	var no_jump: RunSimulation = _simulate_taps(chart, [4.0, 8.0, 10.0], 16.0)
	assert_true(no_jump.is_dead and no_jump.current_beat > 6.0 and no_jump.current_beat < 7.0, "spike under the road")
	var no_flip_up: RunSimulation = _simulate_taps(chart, [4.0, 6.0, 8.0], 16.0)
	assert_true(no_flip_up.is_dead and no_flip_up.current_beat > 11.0 and no_flip_up.current_beat < 11.5,
			"gate under the road")


func test_forgiven_hit_puts_player_on_the_run_side() -> void:
	var chart: LevelChart = _run_chart()
	var stayed_under: RunSimulation = _simulate_taps(chart, [4.0, 6.0, 8.0], 13.0, true)
	assert_eq(stayed_under.hit_hazards.size(), 1)
	assert_false(stayed_under.is_underside(), "missed flip_up: back on the road after the gate")
	var stayed_on_top: RunSimulation = _simulate_taps(chart, [], 5.6, true)
	assert_true(stayed_on_top.is_underside(), "missed flip_down: under the road after the gate")


func test_safe_start_moves_before_the_run() -> void:
	var chart: LevelChart = _run_chart()
	assert_almost_eq(chart.safe_start_beat(7.0), 3.0, 0.0001)
	assert_almost_eq(chart.safe_start_beat(12.5), 12.5, 0.0001, "gate under the road already passed")


func test_unclosed_run_fails() -> void:
	expect_errors(1)
	assert_null(ChartFixtures.make_chart([{"beat": 4, "type": "flip_down"}, {"beat": 6, "type": "jump"}]))


func test_flip_up_without_flip_down_fails() -> void:
	expect_errors(1)
	assert_null(ChartFixtures.make_chart([{"beat": 4, "type": "flip_up"}]))


func test_only_plain_jumps_under_the_track() -> void:
	expect_errors(1)
	assert_null(ChartFixtures.make_chart([{"beat": 4, "type": "flip_down"}, {"beat": 6, "type": "dodge_left"},
			{"beat": 10, "type": "flip_up"}]))


func test_run_needs_unbroken_road() -> void:
	expect_errors(1)
	var terrain: Array[Dictionary] = [{"beat": 7, "gap": true}, {"beat": 7.5, "height": 0}]
	assert_null(ChartFixtures.make_chart([{"beat": 4, "type": "flip_down"}, {"beat": 10, "type": "flip_up"}], 120.0,
			7.0, 16.0, terrain))
