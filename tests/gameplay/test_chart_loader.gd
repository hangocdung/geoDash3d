extends TestCase


func test_action_event_creates_cue_and_paired_hazard() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "jump"}])
	assert_not_null(chart)
	assert_eq(chart.cues.size(), 1)
	assert_eq(chart.cues[0].action.id, &"jump")
	assert_eq(chart.hazards.size(), 1)
	assert_eq(chart.hazards[0].hazard.id, &"spike")
	assert_almost_eq(chart.hazards[0].beat, 4.5)
	assert_almost_eq(chart.hazards[0].distance, 4.5 * 7.0)


func test_hazard_none_creates_only_cue() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([{"beat": 4, "type": "dash", "hazard": "none"}])
	assert_eq(chart.cues.size(), 1)
	assert_eq(chart.hazards.size(), 0)


func test_events_are_sorted() -> void:
	var chart: LevelChart = ChartFixtures.make_chart([
		{"beat": 8, "type": "jump"}, {"beat": 2, "type": "dash"}, {"beat": 5, "type": "camera", "shot": "chase"},
	])
	assert_almost_eq(chart.cues[0].beat, 2.0)
	assert_almost_eq(chart.cues[1].beat, 8.0)
	assert_true(chart.hazards[0].distance < chart.hazards[1].distance)
	assert_eq(chart.camera_cues[0].shot, &"chase")


func test_unknown_event_type_fails() -> void:
	expect_errors(1)
	assert_null(ChartFixtures.make_chart([{"beat": 1, "type": "teleport"}]))


func test_speed_changes_affect_distance() -> void:
	var text: String = JSON.stringify({
		"version": 1, "song": "x.mp3", "end_beat": 16,
		"tempo": [{"beat": 0, "bpm": 120}],
		"speed": [{"beat": 0, "units_per_beat": 4}, {"beat": 8, "units_per_beat": 10}],
	})
	var chart: LevelChart = ChartLoader.parse_text(text, GameplayConfig.create_default())
	assert_almost_eq(chart.distance_at(8.0), 32.0)
	assert_almost_eq(chart.distance_at(10.0), 52.0)
	assert_almost_eq(chart.beat_at_distance(52.0), 10.0)
	assert_almost_eq(chart.distance_at(-2.0), -8.0)
