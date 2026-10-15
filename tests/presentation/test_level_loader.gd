# Level loading off the main thread: LevelLoader builds the chart, stream, track and mesh arrays on a worker, the
# result matches a direct load, fits only the same chart and quality, and a missing chart fails cleanly.
# Related: src/presentation/level/level_loader.gd, src/presentation/track/track_view.gd
extends TestCase

const CHART: String = "res://assets/music/the_dawn_assembly.chart.json"
const TIMEOUT_MSEC: int = 60000


func _finish(loader: LevelLoader) -> bool:
	var deadline: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while not loader.is_done():
		if Time.get_ticks_msec() > deadline:
			return false
		OS.delay_msec(5)
	return true


func test_loads_everything_on_a_worker() -> void:
	var config: GameplayConfig = GameplayConfig.create_for_play()
	var loader := LevelLoader.new(CHART, config, QualityTier.Tier.MEDIUM).start()
	assert_true(_finish(loader), "finished in time")
	assert_false(loader.failed())
	assert_almost_eq(loader.progress, 1.0, 0.0001)
	assert_true(loader.stream != null)
	assert_true(loader.track_geometry.road.size() > 0, "road chunks")
	var direct: LevelChart = ChartLoader.load_file(CHART, config)
	assert_eq(loader.chart.cues.size(), direct.cues.size(), "same cues as a direct load")
	assert_almost_eq(loader.chart.end_beat, direct.end_beat, 0.0001)
	assert_true(loader.matches(CHART, QualityTier.Tier.MEDIUM))
	assert_false(loader.matches(CHART, QualityTier.Tier.LOW), "another tier builds another track")
	assert_false(loader.matches("res://assets/music/fault_line.chart.json", QualityTier.Tier.MEDIUM))


func test_road_arrays_have_vertices() -> void:
	var loader := LevelLoader.new(CHART, GameplayConfig.create_for_play(), QualityTier.Tier.HIGH).start()
	assert_true(_finish(loader))
	var arrays: Array = loader.track_geometry.road[0]
	assert_eq(arrays.size(), Mesh.ARRAY_MAX)
	assert_true((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() >= 3)


func test_missing_chart_fails() -> void:
	expect_errors(1)
	var loader := LevelLoader.new("res://assets/music/no_such_song.chart.json", GameplayConfig.create_for_play(),
			QualityTier.Tier.LOW).start()
	assert_true(_finish(loader))
	assert_true(loader.failed())
	assert_true(loader.chart == null)
