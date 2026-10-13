extends TestCase


func _learner_with(samples: Array[float]) -> AutoOffsetLearner:
	var learner := AutoOffsetLearner.new()
	for sample: float in samples:
		learner.add_sample(sample)
	return learner


func test_bluetooth_sized_offset_is_corrected_from_three_taps() -> void:
	var learner: AutoOffsetLearner = _learner_with([0.21, 0.2, 0.19])
	assert_almost_eq(learner.compute_adjustment(), 0.18, 0.001)


func test_medium_offset_needs_more_taps_and_is_damped() -> void:
	var few: AutoOffsetLearner = _learner_with([0.04, 0.042, 0.038, 0.041, 0.039])
	assert_almost_eq(few.compute_adjustment(), 0.0, 0.0001, "5 taps are not enough for 40 ms")
	var samples: Array[float] = []
	for index: int in 8:
		samples.append(0.04 + (0.004 if index % 2 == 0 else -0.004))
	assert_almost_eq(_learner_with(samples).compute_adjustment(), 0.028, 0.002, "70% of the median")


func test_tiny_or_noisy_errors_are_ignored() -> void:
	var tiny: Array[float] = []
	for index: int in 30:
		tiny.append(0.006)
	assert_almost_eq(_learner_with(tiny).compute_adjustment(), 0.0, 0.0001, "inside the dead band")
	var noisy: Array[float] = []
	for index: int in 20:
		noisy.append(0.06 if index % 2 == 0 else -0.04)
	assert_almost_eq(_learner_with(noisy).compute_adjustment(), 0.0, 0.0001, "too inconsistent")


func test_shift_removes_applied_correction() -> void:
	var learner: AutoOffsetLearner = _learner_with([0.21, 0.2, 0.19])
	var adjustment: float = learner.compute_adjustment()
	learner.shift(adjustment)
	assert_almost_eq(learner.compute_adjustment(), 0.0, 0.0001, "residual 20 ms with 3 taps is below the bar")


func test_simulation_reports_timing_of_unmatched_late_taps() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}])
	var simulation := RunSimulation.new(chart, GameplayConfig.create_default(), -1.0)
	var errors: Array[float] = []
	simulation.tap_timed.connect(func(error_sec: float) -> void: errors.append(error_sec))
	simulation.tap(4.4)  # 200 ms late at 120 BPM: outside the cue window, still measured
	assert_eq(errors.size(), 1)
	assert_almost_eq(errors[0], 0.2, 0.0001)
	simulation.tap(6.0)  # 1 s from the cue: ignored
	assert_eq(errors.size(), 1)
