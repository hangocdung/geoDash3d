# Terrain gameplay: ledges, gaps, falls, jump orbs, jump pads and fast stairs (gameplay_v3.md).
# Charts run at 120 BPM and 7 units/beat, so the player's half length (0.38) is ~0.054 beat.
# Related: src/gameplay/simulation/run_simulation.gd, src/gameplay/simulation/vertical_motion.gd
extends TestCase

const STEP_EDGE_LEAD: float = 0.55


func _run(chart: LevelChart, taps: Array[float], until_beat: float) -> RunSimulation:
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	for beat: float in taps:
		simulation.tap(beat)
	simulation.advance_to(until_beat)
	return simulation


func _death_index(chart: LevelChart, taps: Array[float], until_beat: float) -> int:
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var deaths: Array[int] = []
	simulation.player_died.connect(func(hazard_index: int, _beat: float) -> void: deaths.append(hazard_index))
	for beat: float in taps:
		simulation.tap(beat)
	simulation.advance_to(until_beat)
	return deaths[0] if not deaths.is_empty() else HazardChecker.NO_HAZARD


func _landings(chart: LevelChart, taps: Array[float], until_beat: float) -> Array[Vector2]:
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var landings: Array[Vector2] = []
	simulation.player_landed.connect(func(beat: float, airtime: float) -> void:
		landings.append(Vector2(beat, airtime)))
	for beat: float in taps:
		simulation.tap(beat)
	simulation.advance_to(until_beat)
	return landings


## Three steps of +1.5, one every 0.75 beat from beat 4, then a long top that ends in a drop.
func _stairs_chart() -> LevelChart:
	var events: Array[Dictionary] = []
	var terrain: Array[Dictionary] = []
	for step: int in 3:
		var cue: float = 4.0 + 0.75 * float(step)
		events.append({"beat": cue, "type": "jump", "hazard": "none"})
		terrain.append({"beat": cue + STEP_EDGE_LEAD, "height": 1.5 * float(step + 1)})
	terrain.append({"beat": 9.0, "height": 0})
	return ChartFixtures.make_chart(events, 120.0, 7.0, 14.0, terrain)


## Jump at 4, orb at the apex (4.5), then a platform at height 2 from beat 5 to 8.
func _orb_chart() -> LevelChart:
	return ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"}, {"beat": 4.5, "type": "orb"}],
			120.0, 7.0, 12.0, [{"beat": 5.0, "height": 2.0}, {"beat": 8.0, "height": 0}])


func test_flat_jump_lands_after_its_duration() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"}])
	var landings: Array[Vector2] = _landings(chart, [4.0], 8.0)
	assert_eq(landings.size(), 1)
	assert_almost_eq(landings[0].x, 5.0, 0.0001)
	assert_almost_eq(landings[0].y, 1.0, 0.0001)


func test_jump_onto_a_step_lands_early() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"}], 120.0, 7.0,
			12.0, [{"beat": 4.0 + STEP_EDGE_LEAD, "height": 1.5}])
	var simulation: RunSimulation = _run(chart, [4.0], 6.0)
	assert_false(simulation.is_dead)
	assert_almost_eq(simulation.player_height_at(6.0), 1.5, 0.0001)
	assert_almost_eq(_landings(chart, [4.0], 6.0)[0].x, 4.75, 0.0001, "lands 3/4 beat after take-off")


func test_running_into_a_step_dies() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"}], 120.0, 7.0,
			12.0, [{"beat": 4.0 + STEP_EDGE_LEAD, "height": 1.5}])
	assert_eq(_death_index(chart, [], 6.0), RunSimulation.TERRAIN_HIT)


func test_running_off_a_ledge_falls_and_lands() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([], 120.0, 7.0, 12.0,
			[{"beat": -8.0, "height": 1.5}, {"beat": 6.0, "height": 0}])
	var simulation: RunSimulation = _run(chart, [], 8.0)
	assert_false(simulation.is_dead)
	assert_almost_eq(simulation.player_height_at(8.0), 0.0, 0.0001)
	var landings: Array[Vector2] = _landings(chart, [], 8.0)
	assert_eq(landings.size(), 1)
	assert_almost_eq(landings[0].y, sqrt(2.0 * 1.5 / 16.0), 0.0001, "free fall of 1.5 units")


func test_gap_needs_a_jump() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"}], 120.0, 7.0,
			12.0, [{"beat": 4.25, "gap": true}, {"beat": 4.75, "height": 0}])
	assert_eq(_death_index(chart, [], 8.0), RunSimulation.TERRAIN_HIT)
	for offset: float in [-0.2, 0.0, 0.2]:
		assert_false(_run(chart, [4.0 + offset], 8.0).is_dead, "tap offset %.2f beat" % offset)


func test_orb_relaunches_in_mid_air() -> void:
	var chart: LevelChart = _orb_chart()
	var simulation: RunSimulation = _run(chart, [4.0, 4.5], 7.0)
	assert_false(simulation.is_dead)
	assert_almost_eq(simulation.player_height_at(7.0), 2.0, 0.0001, "on the platform")
	assert_almost_eq(_landings(chart, [4.0, 4.5], 7.0)[0].x, 5.5, 0.0001)
	assert_eq(_death_index(chart, [4.0], 7.0), RunSimulation.TERRAIN_HIT, "no orb tap: hits the platform side")


func test_tap_in_mid_air_without_orb_does_nothing() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump", "hazard": "none"}])
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var starts: Array[float] = []
	simulation.action_started.connect(func(_action: ActionDefinition, beat: float, _cue: int) -> void:
		starts.append(beat))
	simulation.tap(4.0)
	simulation.tap(4.5)
	simulation.advance_to(8.0)
	assert_eq(starts.size(), 1, "only the take-off; the second tap is too early to buffer")


func test_pad_launches_onto_high_ground_without_tap() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "pad"}], 120.0, 7.0, 12.0,
			[{"beat": 4.75, "height": 4.0}, {"beat": 8.0, "height": 0}])
	var simulation: RunSimulation = _run(chart, [], 6.0)
	assert_false(simulation.is_dead)
	assert_almost_eq(simulation.player_height_at(6.0), 4.0, 0.0001)
	var trigger_beat: float = 4.0 - (0.6 + 0.38) / 7.0
	assert_almost_eq(_landings(chart, [], 6.0)[0].x, trigger_beat + 1.0, 0.0001)


func test_fast_stairs_tolerate_timing_errors() -> void:
	var chart: LevelChart = _stairs_chart()
	assert_false(Autoplay.run_full(chart, GameplayConfig.create_default(), false).is_dead)
	for offset: float in [-0.15, 0.15]:
		var taps: Array[float] = [4.0 + offset, 4.75 + offset, 5.5 + offset]
		var simulation: RunSimulation = _run(chart, taps, 12.0)
		assert_false(simulation.is_dead, "offset %.2f died at %.2f" % [offset, simulation.current_beat])
		assert_almost_eq(simulation.player_height_at(11.0), 0.0, 0.0001, "dropped back to the road")
	assert_true(_run(chart, [4.0, 5.05, 5.8], 12.0).is_dead, "second jump 150 ms late hits the next step")


func test_spike_stands_on_the_platform() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}], 120.0, 7.0, 12.0,
			[{"beat": -8.0, "height": 2.0}])
	assert_almost_eq(chart.hazards[0].base_height, 2.0, 0.0001)
	assert_eq(_death_index(chart, [], 8.0), 0, "the spike, not the terrain")
	assert_false(_run(chart, [4.0], 8.0).is_dead)


func test_result_is_independent_of_frame_rate() -> void:
	var events: Array[Dictionary] = [{"beat": 12, "type": "pad"}]
	var terrain: Array[Dictionary] = [{"beat": 12.75, "height": 4.0}, {"beat": 15.0, "height": 0}]
	for step: int in 3:
		events.append({"beat": 4.0 + 0.75 * float(step), "type": "jump", "hazard": "none"})
		terrain.append({"beat": 4.55 + 0.75 * float(step), "height": 1.5 * float(step + 1)})
	terrain.append({"beat": 8.0, "height": 0})
	terrain.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["beat"]) < float(b["beat"]))
	var chart: LevelChart = ChartFixtures.make_chart(events, 120.0, 7.0, 18.0, terrain)
	var taps: Array[float] = [4.06, 4.79, 5.51]
	var results: Array[Array] = []
	for frame_step: float in [0.37, 0.011]:
		var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
		var landings: Array[float] = []
		simulation.player_landed.connect(func(beat: float, _airtime: float) -> void: landings.append(beat))
		var beat: float = -1.0
		var tap_index: int = 0
		while beat < 18.0:
			beat += frame_step
			while tap_index < taps.size() and taps[tap_index] <= beat:
				simulation.tap(taps[tap_index])
				tap_index += 1
			simulation.advance_to(beat)
		assert_false(simulation.is_dead, "frame step %.3f died at %.2f" % [frame_step, simulation.current_beat])
		results.append(landings)
	assert_eq(results[0], results[1])


func test_loader_rejects_dodge_on_raised_ground() -> void:
	expect_errors(1)
	assert_null(ChartFixtures.make_chart([{"beat": 4, "type": "dodge_left"}], 120.0, 7.0, 12.0,
			[{"beat": -8.0, "height": 1.0}]))


func test_reference_run_records_cue_heights_and_air_time() -> void:
	var chart: LevelChart = _orb_chart()
	assert_almost_eq(chart.cue_heights[0], 0.0, 0.0001)
	assert_almost_eq(chart.cue_heights[1], 2.0, 0.0001, "the orb sits at the apex")
	assert_almost_eq(chart.airborne_ranges[0].x, 4.0, 0.0001)
	assert_almost_eq(chart.airborne_ranges[0].y, 5.5, 0.0001)


func test_safe_start_is_never_in_mid_air() -> void:
	var chart: LevelChart = _orb_chart()
	assert_almost_eq(chart.safe_start_beat(4.7), 3.5, 0.0001, "a beat before the orb, still before the take-off")
	assert_almost_eq(chart.safe_start_beat(6.0), 6.0, 0.0001, "standing on the platform")
	var ledge: LevelChart = ChartFixtures.make_chart([], 120.0, 7.0, 12.0,
			[{"beat": -8.0, "height": 1.5}, {"beat": 6.0, "height": 0}])
	assert_true(ledge.safe_start_beat(6.3) < 6.0, "not while falling off the ledge")


func test_jump_buffered_during_a_flip_still_clears_the_next_spike() -> void:
	# Regression: the buffered jump started on the grid beat the flip ended and was "landed" at once.
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "flip"}, {"beat": 6, "type": "jump"}])
	for offset: float in [0.0, -0.02, -0.15]:
		assert_false(_run(chart, [4.0, 6.0 + offset], 9.0).is_dead, "jump offset %.2f beat" % offset)
