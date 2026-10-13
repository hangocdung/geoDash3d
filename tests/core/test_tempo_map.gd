extends TestCase


func test_constant_tempo_maps_beats_to_seconds() -> void:
	var tempo: TempoMap = TempoMap.constant(120.0, 0.5)
	assert_almost_eq(tempo.beat_to_time(0.0), 0.5)
	assert_almost_eq(tempo.beat_to_time(4.0), 2.5)
	assert_almost_eq(tempo.beat_to_time(-2.0), -0.5)
	assert_almost_eq(tempo.time_to_beat(2.5), 4.0)


func test_tempo_change_accumulates_time() -> void:
	var tempo: TempoMap = TempoMap.create(PackedFloat64Array([0.0, 8.0]), PackedFloat64Array([120.0, 60.0]), 0.0)
	assert_almost_eq(tempo.beat_to_time(8.0), 4.0)
	assert_almost_eq(tempo.beat_to_time(10.0), 6.0)
	assert_almost_eq(tempo.time_to_beat(6.0), 10.0)
	assert_almost_eq(tempo.bpm_at(9.0), 60.0)
	assert_almost_eq(tempo.bpm_at(1.0), 120.0)


func test_round_trip_is_stable() -> void:
	var tempo: TempoMap = TempoMap.create(
			PackedFloat64Array([0.0, 3.5, 17.0]), PackedFloat64Array([97.0, 141.0, 120.0]), 0.123)
	for beat: float in [-4.0, 0.0, 1.25, 3.5, 9.75, 17.0, 300.0]:
		assert_almost_eq(tempo.time_to_beat(tempo.beat_to_time(beat)), beat, 0.000001, "beat %f" % beat)


func test_invalid_tempo_is_rejected() -> void:
	expect_errors(2)
	assert_null(TempoMap.create(PackedFloat64Array([0.0]), PackedFloat64Array([0.0]), 0.0))
	assert_null(TempoMap.create(PackedFloat64Array([0.0, 0.0]), PackedFloat64Array([120.0, 100.0]), 0.0))
