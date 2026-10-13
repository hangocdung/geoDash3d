extends TestCase


func test_tap_error_uses_nearest_beat() -> void:
	var tempo: TempoMap = TempoMap.constant(100.0, 0.5)  # beats every 0.6 s from 0.5 s
	assert_almost_eq(CalibrationMath.tap_error(1.13, tempo), 0.03, 0.000001)
	assert_almost_eq(CalibrationMath.tap_error(1.05, tempo), -0.05, 0.000001)


func test_estimate_rejects_outliers() -> void:
	var errors: PackedFloat64Array = [0.031, 0.029, 0.034, 0.027, 0.03, 0.033, 0.026, 0.032, 0.03, 0.25, -0.2]
	var estimate: CalibrationMath.Estimate = CalibrationMath.estimate(errors)
	assert_true(estimate.is_valid)
	assert_eq(estimate.accepted_count, 9)
	assert_almost_eq(estimate.offset_sec, 0.0302, 0.001)
	assert_true(estimate.spread_sec < 0.005)


func test_estimate_needs_enough_taps() -> void:
	var estimate: CalibrationMath.Estimate = CalibrationMath.estimate(PackedFloat64Array([0.01, 0.02, 0.015]))
	assert_false(estimate.is_valid)


func test_click_track_places_clicks_on_beats() -> void:
	var tempo: TempoMap = TempoMap.constant(120.0, 0.1)
	var stream: AudioStreamWAV = ClickTrack.generate(tempo, 1.0)
	assert_not_null(stream)
	assert_eq(stream.data.size(), 44100 * 2)
	var click_frame: int = roundi(0.1 * ClickTrack.MIX_RATE)
	assert_eq(stream.data.decode_s16((click_frame - 10) * 2), 0, "silence before the first click")
	var peak: int = 0
	for frame: int in range(click_frame, click_frame + 200):
		peak = maxi(peak, absi(stream.data.decode_s16(frame * 2)))
	assert_true(peak > 10000, "click is audible right at the beat")
	assert_eq(stream.data.decode_s16(roundi(0.35 * ClickTrack.MIX_RATE) * 2), 0, "silence between beats")
