# Track shapes beyond straight / turn / slope: helix, loop, roll, wave, banked turns; their validation and
# the self-overlap check (also run on every shipped chart).
# Related: src/gameplay/track/track_path.gd, src/gameplay/track/track_clearance.gd
extends TestCase

const MUSIC_DIRECTORY: String = "res://assets/music"
const SPEED: float = 8.0


func _chart_with_track(track: Array[Dictionary]) -> LevelChart:
	var text: String = JSON.stringify({
		"version": 1, "song": "x.mp3", "end_beat": 64,
		"tempo": [{"beat": 0, "bpm": 120}],
		"speed": [{"beat": 0, "units_per_beat": SPEED}],
		"track": track,
	})
	return ChartLoader.parse_text(text, GameplayConfig.create_default())


func _path(track: Array[Dictionary]) -> TrackPath:
	return TrackPath.build(_chart_with_track(track))


func _assert_continuous(path: TrackPath) -> void:
	var previous: Transform3D = path.transform_at(path.start_distance)
	var distance: float = path.start_distance + 1.0
	while distance < path.end_distance:
		var current: Transform3D = path.transform_at(distance)
		assert_true(current.origin.distance_to(previous.origin) < 1.1, "jump at distance %.1f" % distance)
		assert_true(current.basis.x.dot(previous.basis.x) > 0.95, "kink at distance %.1f" % distance)
		assert_almost_eq(current.basis.determinant(), 1.0, 0.01, "frame stays orthonormal")
		previous = current
		distance += 1.0


func test_helix_turns_and_climbs_without_running_into_itself() -> void:
	var path: TrackPath = _path([{"beat": 0, "shape": "straight"},
			{"beat": 4, "shape": "helix", "angle_deg": 360, "rise": 18}, {"beat": 20, "shape": "straight"}])
	var end: Transform3D = path.transform_at(SPEED * 24.0)
	assert_almost_eq(end.origin.y, 18.0, 0.1, "full rise")
	assert_vec3_almost_eq(end.basis.x, Vector3.RIGHT, 0.01, "same heading after a full turn")
	assert_true(path.transform_at(SPEED * 12.0).basis.x.y > 0.05, "climbing mid-helix")
	_assert_continuous(path)
	assert_true(is_nan(TrackClearance.new(path).find_self_overlap(1.5)), "upper turn clears the lower one")


func test_flat_full_turn_is_reported_as_overlap() -> void:
	var path: TrackPath = _path([{"beat": 0, "shape": "straight"},
			{"beat": 4, "shape": "turn", "angle_deg": 360}, {"beat": 12, "shape": "straight"}])
	assert_false(is_nan(TrackClearance.new(path).find_self_overlap(1.5)))


func test_loop_goes_over_the_top_and_lands_beside_its_entry() -> void:
	var path: TrackPath = _path([{"beat": 0, "shape": "straight"},
			{"beat": 4, "shape": "loop", "lateral": 7}, {"beat": 16, "shape": "straight"}])
	var top: Transform3D = path.transform_at(SPEED * 10.0)
	assert_true(top.basis.y.y < -0.9, "upside down at the top")
	assert_true(top.origin.y > 20.0, "top of the loop is high above the road")
	var after: Transform3D = path.transform_at(SPEED * 20.0)
	assert_almost_eq(after.origin.y, 0.0, 0.1, "back on the ground")
	assert_almost_eq(after.origin.z, 7.0, 0.1, "shifted aside by 'lateral'")
	assert_vec3_almost_eq(after.basis.y, Vector3.UP, 0.01)
	_assert_continuous(path)
	assert_true(is_nan(TrackClearance.new(path).find_self_overlap(1.5)))


func test_roll_turns_the_road_over_and_back() -> void:
	var path: TrackPath = _path([{"beat": 0, "shape": "straight"},
			{"beat": 4, "shape": "roll", "roll_deg": 360}, {"beat": 8, "shape": "straight"}])
	assert_true(path.transform_at(SPEED * 6.0).basis.y.y < -0.9, "upside down halfway")
	assert_almost_eq(path.transform_at(SPEED * 6.0).origin.y, 0.0, 0.001, "the road axis stays straight")
	assert_vec3_almost_eq(path.transform_at(SPEED * 10.0).basis.y, Vector3.UP, 0.01)
	assert_false(path.is_upright_at(SPEED * 6.0))
	assert_true(path.is_upright_at(SPEED * 10.0))


func test_wave_hills_rise_and_return() -> void:
	var path: TrackPath = _path([{"beat": 0, "shape": "straight"},
			{"beat": 4, "shape": "wave", "amplitude": 3, "count": 2}, {"beat": 12, "shape": "straight"}])
	assert_almost_eq(path.transform_at(SPEED * 6.0).origin.y, 3.0, 0.1, "first crest")
	assert_almost_eq(path.transform_at(SPEED * 8.0).origin.y, 0.0, 0.1, "valley between the hills")
	assert_almost_eq(path.transform_at(SPEED * 14.0).origin.y, 0.0, 0.1)
	_assert_continuous(path)


func test_banked_turn_leans_into_the_turn() -> void:
	var path: TrackPath = _path([{"beat": 0, "shape": "straight"},
			{"beat": 4, "shape": "turn", "angle_deg": 90, "bank_deg": 25}, {"beat": 8, "shape": "straight"}])
	var middle: Transform3D = path.transform_at(SPEED * 6.0)
	assert_true(middle.basis.z.y > 0.3, "left turn lifts the right-hand side")
	assert_vec3_almost_eq(path.transform_at(SPEED * 10.0).basis.y, Vector3.UP, 0.01, "level again after")
	assert_vec3_almost_eq(path.transform_at(SPEED * 10.0).basis.x, Vector3.FORWARD, 0.01, "still a 90° turn")


func test_shapes_that_would_hit_themselves_are_rejected() -> void:
	expect_errors(2)
	assert_null(_chart_with_track([{"beat": 0, "shape": "helix", "angle_deg": 360, "rise": 6}]), "flat helix")
	assert_null(_chart_with_track([{"beat": 0, "shape": "loop", "lateral": 1}]), "loop without side shift")


func test_shipped_tracks_never_run_into_themselves() -> void:
	var config: GameplayConfig = GameplayConfig.create_default()
	for file_name: String in DirAccess.get_files_at(MUSIC_DIRECTORY):
		if not file_name.ends_with(".chart.json"):
			continue
		var chart: LevelChart = ChartLoader.load_file(MUSIC_DIRECTORY.path_join(file_name), config)
		var path: TrackPath = TrackPath.build(chart)
		var overlap: float = TrackClearance.new(path).find_self_overlap(config.track_width * 0.5)
		assert_true(is_nan(overlap), "%s: track runs into itself at beat %.1f" % [file_name,
				chart.beat_at_distance(overlap) if not is_nan(overlap) else 0.0])


func test_low_tier_flattens_camera_turning_shapes() -> void:
	var chart: LevelChart = _chart_with_track([{"beat": 0, "shape": "straight"},
			{"beat": 4, "shape": "helix", "angle_deg": 360, "rise": 18}, {"beat": 20, "shape": "loop", "lateral": 7},
			{"beat": 32, "shape": "roll"}, {"beat": 40, "shape": "turn", "angle_deg": 90, "bank_deg": 25},
			{"beat": 44, "shape": "straight"}])
	var flat: TrackPath = TrackPath.build(chart, -INF, true)
	var distance: float = 0.0
	while distance < SPEED * 48.0:
		assert_true(flat.is_upright_at(distance, 0.9), "road stays upright at %.1f" % distance)
		distance += 2.0
	assert_almost_eq(flat.transform_at(SPEED * 20.0).origin.y, 18.0, 0.1, "the helix still climbs")
	assert_vec3_almost_eq(flat.transform_at(SPEED * 12.0).basis.x.normalized() * Vector3(1, 0, 1),
			Vector3.RIGHT * flat.transform_at(SPEED * 12.0).basis.x.normalized().x, 0.01, "no yaw during the helix")
	assert_vec3_almost_eq(flat.transform_at(SPEED * 46.0).basis.x, Vector3.FORWARD, 0.01, "turns keep their heading")
	assert_eq(chart.track_segments[1].shape, ChartItems.TrackSegment.Shape.HELIX, "the chart itself is untouched")
