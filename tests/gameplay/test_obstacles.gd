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
