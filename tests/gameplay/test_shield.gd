# Combo and shields: hits build the combo, a miss resets it, every `shield_combo` hits charge a shield that
# absorbs one fatal hit (hazards shatter; terrain puts the player back on the perfect run, still on beat).
# Related: src/gameplay/simulation/combo_shield.gd, src/gameplay/simulation/run_simulation.gd
extends TestCase


## Default config with a shield every 2 hits, so fixtures stay short.
func _config() -> GameplayConfig:
	var config: GameplayConfig = GameplayConfig.create_default()
	config.shield_combo = 2
	return config


func _run(chart: LevelChart, taps: Array[float], until_beat: float, invincible: bool = false) -> RunSimulation:
	var simulation := RunSimulation.new(chart, _config(), -1.0)
	simulation.invincible = invincible
	for beat: float in taps:
		simulation.tap(beat)
	simulation.advance_to(until_beat)
	return simulation


## Two warm-up jumps (beats 4 and 6, nothing to clear) that charge the shield, then `events`.
func _chart(events: Array[Dictionary], terrain: Array[Dictionary] = [], end_beat: float = 20.0) -> LevelChart:
	var all_events: Array[Dictionary] = [{"beat": 4, "type": "jump", "hazard": "none"},
			{"beat": 6, "type": "jump", "hazard": "none"}]
	all_events.append_array(events)
	return ChartFixtures.make_chart(all_events, 120.0, 7.0, end_beat, terrain)


func test_combo_counts_hits_and_a_miss_resets_it() -> void:
	var chart: LevelChart = _chart([{"beat": 8, "type": "jump", "hazard": "none"},
			{"beat": 10, "type": "jump", "hazard": "none"}])
	var simulation: RunSimulation = _run(chart, [4.0, 6.0, 10.0], 12.0)
	assert_eq(simulation.streak.combo, 1, "the miss at 8 reset it")
	assert_eq(simulation.streak.max_combo, 2)


func test_shield_charges_every_n_hits_up_to_the_cap() -> void:
	var chart: LevelChart = _chart([{"beat": 8, "type": "jump", "hazard": "none"},
			{"beat": 10, "type": "jump", "hazard": "none"}])
	var simulation := RunSimulation.new(chart, _config(), -1.0)
	var charges: Array[int] = []
	simulation.shield_changed.connect(func(shields: int) -> void: charges.append(shields))
	for beat: float in [4.0, 6.0, 8.0, 10.0]:
		simulation.tap(beat)
	simulation.advance_to(12.0)
	assert_eq(simulation.streak.shields, 1)
	assert_eq(charges, [1] as Array[int], "charged once at hit 2; hit 4 finds the stock full")


func test_shield_shatters_a_spike_once() -> void:
	var chart: LevelChart = _chart([{"beat": 8, "type": "jump"}, {"beat": 12, "type": "jump"}])
	var simulation: RunSimulation = _run(chart, [4.0, 6.0], 11.0)
	assert_false(simulation.is_dead, "the shield took the spike at 8.5")
	assert_eq(simulation.hit_hazards, PackedInt32Array([0]))
	assert_eq(simulation.streak.shields, 0)
	assert_eq(simulation.streak.combo, 0, "an absorbed hit breaks the combo")
	simulation.advance_to(14.0)
	assert_true(simulation.is_dead, "no shield left for the spike at 12.5")


func test_without_a_shield_the_spike_kills() -> void:
	var chart: LevelChart = _chart([{"beat": 8, "type": "jump"}])
	assert_true(_run(chart, [4.0], 11.0).is_dead, "one hit is not enough to charge")


func test_shield_puts_a_player_who_missed_the_orb_on_the_platform() -> void:
	var chart: LevelChart = _chart([{"beat": 10, "type": "jump", "hazard": "none"}, {"beat": 10.5, "type": "orb"}],
			[{"beat": 11.0, "height": 2.0}, {"beat": 14.0, "height": 0}])
	var simulation := RunSimulation.new(chart, _config(), -1.0)
	var used: Array[int] = []
	simulation.shield_used.connect(func(hazard_index: int, _beat: float) -> void: used.append(hazard_index))
	for beat: float in [4.0, 6.0, 10.0]:
		simulation.tap(beat)
	simulation.advance_to(13.0)
	assert_false(simulation.is_dead)
	assert_eq(used, [RunSimulation.TERRAIN_HIT] as Array[int])
	assert_almost_eq(simulation.player_height_at(13.0), 2.0, 0.0001, "on the platform like the perfect run")


func test_rescued_player_stays_on_beat_for_the_next_cue() -> void:
	# Jump + two orbs over a pit onto a platform 4 high, then a step up at 13: the orbs are not tapped.
	var chart: LevelChart = _chart([{"beat": 10, "type": "jump", "hazard": "none"}, {"beat": 10.5, "type": "orb"},
			{"beat": 11.0, "type": "orb"}, {"beat": 13, "type": "jump", "hazard": "none"}],
			[{"beat": 10.3, "gap": true}, {"beat": 11.5, "height": 4.0}, {"beat": 13.55, "height": 5.5},
			{"beat": 16.0, "height": 0}])
	var simulation: RunSimulation = _run(chart, [4.0, 6.0, 10.0, 13.0], 15.0)
	assert_false(simulation.is_dead, "died at %.2f" % simulation.current_beat)
	assert_almost_eq(simulation.player_height_at(15.0), 5.5, 0.0001, "the step at 13 was taken on its beat")
	assert_true(_run(chart, [4.0, 6.0, 10.0, 13.0], 15.0).streak.shields == 0)


func test_invincible_runs_never_spend_shields() -> void:
	var chart: LevelChart = _chart([{"beat": 8, "type": "jump"}])
	var simulation: RunSimulation = _run(chart, [4.0, 6.0], 11.0, true)
	assert_eq(simulation.streak.shields, 1)
	assert_eq(simulation.hit_hazards, PackedInt32Array([0]))


func test_reference_states_follow_the_perfect_run() -> void:
	var chart: LevelChart = _chart([{"beat": 10, "type": "jump", "hazard": "none"}, {"beat": 10.5, "type": "orb"}],
			[{"beat": 11.0, "height": 2.0}, {"beat": 14.0, "height": 0}])
	var at_orb_arc: VerticalMotion = chart.reference_motion_at(11.2)
	assert_true(at_orb_arc.airborne)
	assert_almost_eq(at_orb_arc.launch_beat, 10.5, 0.0001, "the arc started by the orb")
	assert_false(chart.reference_motion_at(12.0).airborne, "landed at 11.5")
	assert_null(ChartFixtures.make_chart([{"beat": 4, "type": "jump"}]).reference_motion_at(5.0), "flat chart")
