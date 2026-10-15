# Obstacle variety (GD3-095): spike rows, saw, spiked ceiling, big jump orb and dive orb.
# Charts run at 120 BPM and 7 units/beat (player half length 0.38 = ~0.054 beat).
# Related: src/gameplay/defs/gameplay_config.gd, src/gameplay/simulation/run_simulation.gd
extends TestCase

## Dive orb pattern: jump at 4, dive at the apex (4.5), ceiling from 4.9 (its near edge) on.
const CEILING_EDGE_BEAT: float = 4.9


func _simulate(chart: LevelChart, taps: Array[float], until_beat: float) -> RunSimulation:
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	for beat: float in taps:
		simulation.tap(beat)
	simulation.advance_to(until_beat)
	return simulation


func _landings(chart: LevelChart, taps: Array[float], until_beat: float) -> PackedFloat64Array:
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var landings: PackedFloat64Array = []
	simulation.player_landed.connect(func(beat: float, _airtime: float) -> void: landings.append(beat))
	for beat: float in taps:
		simulation.tap(beat)
	simulation.advance_to(until_beat)
	return landings


func _ceiling_chart() -> LevelChart:
	var ceiling: HazardDefinition = GameplayConfig.create_default().find_hazard(&"ceiling")
	var center_beat: float = CEILING_EDGE_BEAT + ceiling.half_length / 7.0
	return ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"}, {"beat": 4.5, "type": "orb_drop"},
			{"beat": center_beat, "type": "hazard", "hazard": "ceiling"}], 120.0, 7.0, 12.0)


func test_loader_knows_the_new_types() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "spike_double"},
			{"beat": 8, "type": "jump", "hazard": "spike_triple"}, {"beat": 12, "type": "jump", "hazard": "saw"},
			{"beat": 16, "type": "orb_big"}, {"beat": 20, "type": "orb_drop"}])
	assert_not_null(chart)
	assert_eq(chart.hazards.size(), 3)
	assert_true(chart.cues[0].has_hazard)
	assert_eq(chart.cues[3].action.id, &"orb_big")
	assert_true(chart.cues[4].action.air_allowed)


func test_dive_orb_throws_the_player_down() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"},
			{"beat": 4.5, "type": "orb_drop"}], 120.0, 7.0, 12.0)
	var landings: PackedFloat64Array = _landings(chart, [4.0, 4.5], 8.0)
	assert_eq(landings.size(), 1)
	# From the apex (2 up) at 12 units/beat down with gravity 16: (sqrt(144 + 64) - 12) / 16 beats.
	assert_almost_eq(landings[0], 4.5 + (sqrt(208.0) - 12.0) / 16.0, 0.0001)


func test_big_orb_launches_the_pad_arc_from_mid_air() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"},
			{"beat": 4.5, "type": "orb_big"}], 120.0, 7.0, 12.0)
	var simulation: RunSimulation = _simulate(chart, [4.0, 4.5], 5.25)
	assert_almost_eq(simulation.player_height_at(5.25), 2.0 + 4.5, 0.0001, "apex 4.5 above the orb")
	# Back to the road: 12t - 8t² = -2.
	var landings: PackedFloat64Array = _landings(chart, [4.0, 4.5], 8.0)
	assert_almost_eq(landings[0], 4.5 + (12.0 + sqrt(208.0)) / 16.0, 0.0001)


func test_ceiling_kills_a_jump_that_does_not_dive() -> void:
	var chart: LevelChart = _ceiling_chart()
	assert_true(_simulate(chart, [4.0], 8.0).is_dead, "the plain arc runs into the ceiling")
	assert_false(_simulate(chart, [], 8.0).is_dead, "running under it on the road is safe")


func test_diving_under_the_ceiling_survives_late_taps() -> void:
	var chart: LevelChart = _ceiling_chart()
	for dive_beat: float in [4.5, 4.5 + 0.15, 4.5 - 0.15]:
		assert_false(_simulate(chart, [4.0, dive_beat], 8.0).is_dead, "dive at %.2f" % dive_beat)


func test_spike_rows_are_cleared_by_one_jump_with_tolerance() -> void:
	for hazard_id: String in ["spike_double", "spike_triple", "saw"]:
		var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": hazard_id}])
		assert_true(_simulate(chart, [], 6.0).is_dead, "%s kills without a jump" % hazard_id)
		for tap_beat: float in [4.0, 4.0 - 0.15, 4.0 + 0.15]:
			assert_false(_simulate(chart, [tap_beat], 6.0).is_dead, "%s jump at %.2f" % [hazard_id, tap_beat])


func test_model_obstacles_load_and_are_jumped_with_tolerance() -> void:
	# GD3-104: laser fence, swinging axe, spiked mine are jumped like a spike (same or looser window).
	for hazard_id: String in ["laser_fence", "pendulum", "spike_mine", "piston_spikes", "rolling_ball"]:
		var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": hazard_id}])
		assert_not_null(chart, hazard_id)
		assert_true(_simulate(chart, [], 6.0).is_dead, "%s kills without a jump" % hazard_id)
		for tap_beat: float in [4.0, 4.0 - 0.15, 4.0 + 0.15]:
			assert_false(_simulate(chart, [tap_beat], 6.0).is_dead, "%s jump at %.2f" % [hazard_id, tap_beat])


func test_sliding_walls_keep_the_dodge_rule() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "dodge_left", "hazard": "sliding_wall_left"},
			{"beat": 8, "type": "dodge_right", "hazard": "sliding_wall_right"}], 120.0, 7.0, 16.0)
	assert_eq(chart.hazards.size(), 2)
	assert_true(_simulate(chart, [], 14.0).is_dead, "running straight hits the sliding wall")
	assert_false(_simulate(chart, [4.0, 8.0], 14.0).is_dead, "dodging clears both")


func test_crusher_works_like_the_spiked_ceiling() -> void:
	var crusher: HazardDefinition = GameplayConfig.create_default().find_hazard(&"crusher")
	var center_beat: float = CEILING_EDGE_BEAT + crusher.half_length / 7.0
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"},
			{"beat": 4.5, "type": "orb_drop"}, {"beat": center_beat, "type": "hazard", "hazard": "crusher"}],
			120.0, 7.0, 12.0)
	assert_true(_simulate(chart, [4.0], 8.0).is_dead, "a plain jump runs into the press")
	assert_false(_simulate(chart, [4.0, 4.5], 8.0).is_dead, "diving under it survives")


func test_laser_walls_and_ring_gate_keep_the_dodge_and_flip_rules() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "dodge_left", "hazard": "laser_gap_left"},
			{"beat": 8, "type": "dodge_right", "hazard": "laser_gap_right"}, {"beat": 12, "type": "flip", "hazard": "ring_gate"}],
			120.0, 7.0, 20.0)
	assert_eq(chart.hazards.size(), 3)
	assert_true(_simulate(chart, [], 18.0).is_dead, "running straight hits the laser wall")
	assert_false(_simulate(chart, [4.0, 8.0, 12.0], 18.0).is_dead, "dodging and flipping clears them")


func test_roll_goes_all_the_way_around_the_track() -> void:
	var roll: ActionDefinition = GameplayConfig.create_default().find_action(&"roll")
	assert_true(roll.full_turn)
	assert_true(roll.offset_at(0.2).x > 0.5, "over the right-hand edge first")
	assert_true(roll.offset_at(0.5).y < -1.5, "under the track halfway")
	assert_true(roll.offset_at(0.8).x < -0.5, "comes back up the left-hand edge")
	assert_almost_eq(roll.flip_angle(0.9), TAU - PI * roll.hold_amount(0.9), 0.0001)
	var flip: ActionDefinition = GameplayConfig.create_default().find_action(&"flip")
	assert_true(flip.offset_at(0.92).x > 0.5, "a flip wraps back over the edge it went down")


func test_roll_clears_the_sweeping_mace_and_the_falling_block_with_tolerance() -> void:
	for hazard_id: String in ["mace_sweep", "falling_block"]:
		var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "roll", "hazard": hazard_id}], 120.0, 7.0,
				12.0)
		assert_not_null(chart, hazard_id)
		assert_true(_simulate(chart, [], 8.0).is_dead, "%s blocks the road" % hazard_id)
		var jump_chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"},
				{"beat": 5, "type": "hazard", "hazard": hazard_id}], 120.0, 7.0, 12.0)
		assert_true(_simulate(jump_chart, [4.6], 8.0).is_dead, "%s is too tall to jump" % hazard_id)
		for tap_beat: float in [4.0, 4.0 - 0.15, 4.0 + 0.15]:
			assert_false(_simulate(chart, [tap_beat], 8.0).is_dead, "%s roll at %.2f" % [hazard_id, tap_beat])
