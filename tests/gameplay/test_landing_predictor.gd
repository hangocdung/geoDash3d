# LandingPredictor (GD3-258): the landing beat a short time ahead, without changing the simulation.
# Related: src/gameplay/simulation/landing_predictor.gd, src/presentation/level/presentation_router.gd
extends TestCase


func _jump_simulation(advance_beat: float) -> RunSimulation:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}])
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	simulation.tap(4.0)
	simulation.advance_to(advance_beat)
	return simulation


func test_predicts_the_landing_within_reach() -> void:
	var simulation: RunSimulation = _jump_simulation(4.8)
	assert_almost_eq(LandingPredictor.landing_beat(simulation, 0.3), 5.0, 0.011, "flat-ground jump lands a beat later")
	assert_true(is_nan(LandingPredictor.landing_beat(simulation, 0.1)), "landing not within 0.1 beat yet")


func test_is_read_only() -> void:
	var simulation: RunSimulation = _jump_simulation(4.8)
	LandingPredictor.landing_beat(simulation, 0.3)
	assert_true(simulation.is_airborne(), "still in the air after predicting")
	assert_almost_eq(simulation.current_beat, 4.8, 0.0001)
	var landings: Array[float] = []
	simulation.player_landed.connect(func(beat: float, _airtime: float) -> void: landings.append(beat))
	simulation.advance_to(5.5)
	assert_eq(landings.size(), 1)
	assert_almost_eq(landings[0], 5.0, 0.011, "the real landing matches the prediction")


func test_nothing_while_grounded() -> void:
	var simulation: RunSimulation = _jump_simulation(3.0)
	assert_true(is_nan(LandingPredictor.landing_beat(simulation, 1.0)))


func test_predicts_under_the_track() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "flip_down"}, {"beat": 6, "type": "jump"},
			{"beat": 10, "type": "flip_up"}], 120.0, 7.0, 16.0)
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	simulation.tap(4.0)
	simulation.tap(6.0)
	simulation.advance_to(6.9)
	assert_almost_eq(LandingPredictor.landing_beat(simulation, 0.2), 7.0, 0.011)
