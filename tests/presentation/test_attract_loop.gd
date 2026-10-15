# Menu demo length: the first minute, or up to the furthest point reached when that is later, a cleared song plays to
# its end; the music fades out over the last FADE_SEC. Related: src/presentation/level/attract_loop.gd
extends TestCase


## 120 BPM, offset 0: 400 beats = 200 s.
func _chart() -> LevelChart:
	var text: String = JSON.stringify({
		"version": 1, "song": "res://assets/music/the_dawn_assembly.mp3", "end_beat": 400,
		"tempo": [{"beat": 0, "bpm": 120}], "speed": [{"beat": 0, "units_per_beat": 7}],
	})
	return ChartLoader.parse_text(text, GameplayConfig.create_default(), "fixture")


func _record(progress: float, completed: bool = false) -> HighScores.Record:
	var record := HighScores.Record.new()
	record.progress = progress
	record.completed = completed
	return record


func test_new_player_sees_the_first_minute() -> void:
	assert_almost_eq(AttractLoop.end_time(_chart(), _record(0.0)), AttractLoop.PREVIEW_SEC, 0.001)
	assert_almost_eq(AttractLoop.end_time(_chart(), _record(0.2)), AttractLoop.PREVIEW_SEC, 0.001, "40 s < 1 min")


func test_furthest_point_extends_the_demo() -> void:
	assert_almost_eq(AttractLoop.end_time(_chart(), _record(0.5)), 100.0, 0.001, "half of 200 s")


func test_cleared_song_plays_to_the_end() -> void:
	assert_true(is_inf(AttractLoop.end_time(_chart(), _record(1.0, true))))


func test_music_fades_before_the_loop() -> void:
	var demo := AttractLoop.new(_chart(), _record(0.0))
	assert_almost_eq(demo.fade(30.0), 1.0, 0.001)
	assert_almost_eq(demo.fade(AttractLoop.PREVIEW_SEC - AttractLoop.FADE_SEC * 0.5), 0.5, 0.001)
	assert_almost_eq(demo.fade(AttractLoop.PREVIEW_SEC + 1.0), 0.0, 0.001)
	assert_almost_eq(AttractLoop.new(_chart(), _record(1.0, true)).fade(150.0), 1.0, 0.001)
