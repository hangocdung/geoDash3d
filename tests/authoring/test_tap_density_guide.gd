# Suggested note counts: a taps-per-second line over section energy fitted on a reference, scaled per difficulty.
# Related: src/authoring/recorder/tap_density_guide.gd
extends TestCase


func test_fit_recovers_a_line() -> void:
	# 0.5 taps/s at energy 0.2, 1.5 taps/s at energy 0.8 (10 s each).
	var guide: TapDensityGuide = TapDensityGuide.fit([Vector3(0.2, 10.0, 5.0), Vector3(0.8, 10.0, 15.0)] as Array[Vector3])
	assert_almost_eq(guide.slope, 1.0 / 0.6, 0.0001)
	assert_almost_eq(guide.intercept + guide.slope * 0.5, 1.0, 0.0001)
	assert_eq(guide.suggested_taps(0.8, 20.0, 2), 30, "HARD = the reference density")
	assert_eq(guide.suggested_taps(0.8, 20.0, 0), 15, "EASY = half of it")


func test_single_energy_gives_a_flat_density() -> void:
	var guide: TapDensityGuide = TapDensityGuide.fit([Vector3(0.5, 4.0, 4.0), Vector3(0.5, 6.0, 6.0)] as Array[Vector3])
	assert_almost_eq(guide.slope, 0.0)
	assert_eq(guide.suggested_taps(0.9, 10.0, 2), 10)


func test_density_never_goes_negative() -> void:
	var guide: TapDensityGuide = TapDensityGuide.fit([Vector3(0.6, 10.0, 0.0), Vector3(1.0, 10.0, 20.0)] as Array[Vector3])
	assert_eq(guide.suggested_taps(0.0, 10.0, 2), 0)


func test_reference_chart_is_denser_in_loud_sections() -> void:
	var guide: TapDensityGuide = TapDensityGuide.from_reference()
	assert_true(guide.slope > 0.0, "louder sections get more taps")
	assert_true(guide.suggested_taps(0.8, 8.0, 2) > guide.suggested_taps(0.2, 8.0, 2))
	assert_true(guide.suggested_taps(0.8, 8.0, 0) < guide.suggested_taps(0.8, 8.0, 2))
