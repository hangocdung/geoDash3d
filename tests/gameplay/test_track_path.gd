extends TestCase


func _chart_with_track(track: Array[Dictionary]) -> LevelChart:
	var text: String = JSON.stringify({
		"version": 1, "song": "x.mp3", "end_beat": 32,
		"tempo": [{"beat": 0, "bpm": 120}],
		"speed": [{"beat": 0, "units_per_beat": 5}],
		"track": track,
	})
	return ChartLoader.parse_text(text, GameplayConfig.create_default())


func test_straight_track_runs_along_x() -> void:
	var path: TrackPath = TrackPath.build(_chart_with_track([{"beat": 0, "shape": "straight"}]))
	assert_vec3_almost_eq(path.transform_at(0.0).origin, Vector3.ZERO, 0.001)
	assert_vec3_almost_eq(path.transform_at(37.25).origin, Vector3(37.25, 0, 0), 0.001)
	assert_vec3_almost_eq(path.transform_at(-20.0).origin, Vector3(-20, 0, 0), 0.001)
	assert_vec3_almost_eq(path.transform_at(10.0).basis.x, Vector3.RIGHT, 0.001)


func test_quarter_turn_ends_on_circle() -> void:
	# Beats 4..8 at 5 units/beat = 20 units of arc for a 90° left turn.
	var path: TrackPath = TrackPath.build(_chart_with_track([
		{"beat": 0, "shape": "straight"}, {"beat": 4, "shape": "turn", "angle_deg": 90}, {"beat": 8, "shape": "straight"},
	]))
	var radius: float = 20.0 / (PI * 0.5)
	var end: Transform3D = path.transform_at(40.0)
	assert_vec3_almost_eq(end.origin, Vector3(20.0 + radius, 0.0, -radius), 0.05)
	assert_vec3_almost_eq(end.basis.x, Vector3.FORWARD, 0.01)
	assert_vec3_almost_eq(path.transform_at(50.0).origin, Vector3(20.0 + radius, 0.0, -radius - 10.0), 0.05)


func test_slope_rises_smoothly() -> void:
	var path: TrackPath = TrackPath.build(_chart_with_track([
		{"beat": 0, "shape": "straight"}, {"beat": 2, "shape": "slope", "rise": 4}, {"beat": 6, "shape": "straight"},
	]))
	assert_almost_eq(path.transform_at(10.0).origin.y, 0.0, 0.01)
	assert_almost_eq(path.transform_at(20.0).origin.y, 2.0, 0.05)
	assert_almost_eq(path.transform_at(30.0).origin.y, 4.0, 0.05)
	assert_almost_eq(path.transform_at(45.0).origin.y, 4.0, 0.05)
	assert_true(path.transform_at(20.0).basis.x.y > 0.1, "track pitches up mid-slope")
