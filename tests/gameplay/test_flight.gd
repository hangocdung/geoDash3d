# Flight sections (gameplay v4): lift-off, flapping, the spike corridor built from the perfect path, free taps,
# shields, landing after the section, determinism, and the chart rules. 120 BPM, 7 units/beat.
# Related: src/gameplay/simulation/flight_corridor.gd, src/gameplay/simulation/player_body.gd, docs/design/gameplay_v4.md
extends TestCase

const FLY_START: float = 8.0
const FLAP_STEP: float = 0.75


## Flaps every 0.75 beat (holds the height) from half a beat into the section, a jump well after it.
func _chart(fly_end: float = 16.0, extra_events: Array[Dictionary] = []) -> LevelChart:
	var events: Array[Dictionary] = _flaps(fly_end)
	events.append({"beat": fly_end + 4.0, "type": "jump"})
	events.append_array(extra_events)
	return ChartFixtures.make_chart(events, 120.0, 7.0, fly_end + 8.0, [],
			{"fly": [{"beat": FLY_START, "end": fly_end}]})


func _flaps(fly_end: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var beat: float = FLY_START + 0.5
	while beat < fly_end:
		events.append({"beat": beat, "type": "flap"})
		beat += FLAP_STEP
	return events


func _cue_beats(chart: LevelChart) -> Array[float]:
	var beats: Array[float] = []
	for cue: ChartItems.ActionCue in chart.cues:
		beats.append(cue.beat)
	return beats


func _run(chart: LevelChart, taps: Array[float], until_beat: float) -> RunSimulation:
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	for beat: float in taps:
		simulation.tap(beat)
	simulation.advance_to(until_beat)
	return simulation


func test_chart_builds_a_corridor_around_the_path() -> void:
	var chart: LevelChart = _chart()
	assert_not_null(chart)
	assert_not_null(chart.flight, "corridor built")
	var flight: FlightCorridor = chart.flight
	var index: int = flight.bucket_at(chart.distance_at(12.0))
	assert_true(index >= 0)
	assert_true(flight.floors[index] > 0.0 and flight.floors[index] < 2.6, "floor under the path")
	assert_true(flight.ceilings[index] > 3.4 + 0.9, "ceiling over the path")
	assert_true(flight.ceilings[index] - flight.floors[index] >= GameplayConfig.create_default().fly_min_gap - 0.001)
	assert_eq(flight.floors[flight.bucket_at(chart.distance_at(FLY_START + 0.2))], FlightCorridor.NO_FLOOR,
			"no floor spikes at the lift-off")


func test_autoplay_flies_through_and_lands() -> void:
	var chart: LevelChart = _chart()
	var simulation: RunSimulation = Autoplay.run_full(chart, GameplayConfig.create_default(), false)
	assert_false(simulation.is_dead, "autoplay survives")
	assert_true(simulation.is_completed)


func test_flying_flag_follows_the_section() -> void:
	var chart: LevelChart = _chart()
	var changes: Array[Vector2] = []
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	simulation.flight_changed.connect(func(flying: bool, beat: float) -> void:
		changes.append(Vector2(1.0 if flying else 0.0, beat)))
	simulation.advance_to(10.0)
	assert_true(simulation.is_flying())
	assert_true(simulation.is_airborne())
	assert_eq(changes.size(), 1)
	assert_almost_eq(changes[0].y, FLY_START, 0.02)


func test_without_taps_the_player_falls_into_the_floor() -> void:
	var chart: LevelChart = _chart()
	var deaths: Array[float] = []
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	simulation.player_died.connect(func(index: int, beat: float) -> void:
		assert_eq(index, RunSimulation.TERRAIN_HIT)
		deaths.append(beat))
	simulation.advance_to(16.0)
	assert_eq(deaths.size(), 1, "died in the corridor")
	assert_true(deaths[0] > FLY_START + 0.5 and deaths[0] < FLY_START + 3.0, "died at %.3f" % deaths[0])


func test_a_free_tap_flaps_without_a_grade() -> void:
	var chart: LevelChart = _chart()
	var simulation: RunSimulation = _run(chart, [8.5], 8.6)
	var before: float = simulation.player_height_at(8.9)
	simulation.tap(8.9)
	simulation.advance_to(9.0)
	assert_true(simulation.player_height_at(9.0) > before, "the free tap lifted the glider")
	var judged: int = 0
	for count: int in simulation.grade_counts:
		judged += count
	assert_eq(judged, 1, "only the flap cue at 8.5 was judged")


func test_flight_does_not_depend_on_frame_rate() -> void:
	var chart: LevelChart = _chart()
	var taps: Array[float] = _cue_beats(chart)
	var fine := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var coarse := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var next_tap: int = 0
	var beat: float = 0.0
	while beat < 15.0:
		while next_tap < taps.size() and taps[next_tap] <= beat:
			fine.tap(taps[next_tap])
			coarse.tap(taps[next_tap])
			next_tap += 1
		fine.advance_to(beat)
		if fmod(beat, 0.5) < 0.001:
			coarse.advance_to(beat)
		beat += 1.0 / 240.0
	coarse.advance_to(15.0)
	fine.advance_to(15.0)
	assert_almost_eq(fine.player_height_at(15.0), coarse.player_height_at(15.0), 0.000001)


func test_a_shield_puts_the_glider_back_on_the_path() -> void:
	var chart: LevelChart = _chart(32.0)
	var config := GameplayConfig.create_default()
	var simulation := RunSimulation.new(chart, config, -1.0)
	var saves: Array[float] = []
	simulation.shield_used.connect(func(_index: int, beat: float) -> void: saves.append(beat))
	var taps: Array[float] = _cue_beats(chart)
	# Tap the first flaps (enough PERFECTs for a shield), then stop.
	for index: int in config.shield_combo + 2:
		simulation.tap(taps[index])
	simulation.advance_to(taps[config.shield_combo + 2] + 3.0)
	assert_eq(saves.size(), 1, "the shield saved one fall")


func test_the_player_lands_after_the_section() -> void:
	var chart: LevelChart = _chart()
	var landings: Array[float] = []
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	simulation.player_landed.connect(func(beat: float, _airtime: float) -> void: landings.append(beat))
	for beat: float in _cue_beats(chart):
		if beat < 16.0:
			simulation.tap(beat)
	simulation.advance_to(18.0)
	assert_false(simulation.is_dead)
	assert_false(simulation.is_flying())
	assert_false(simulation.is_airborne(), "landed before the next ground cue")
	assert_true(landings[landings.size() - 1] > 16.0)


func test_ground_cue_inside_a_section_is_rejected() -> void:
	expect_errors(1)
	assert_null(_chart(16.0, [{"beat": 12.0, "type": "jump", "hazard": "none"}]))


func test_flap_outside_a_section_is_rejected() -> void:
	expect_errors(1)
	assert_null(_chart(16.0, [{"beat": 22.0, "type": "flap"}]))


func test_ground_cue_right_after_a_section_is_rejected() -> void:
	expect_errors(1)
	assert_null(_chart(16.0, [{"beat": 17.0, "type": "jump", "hazard": "none"}]))
