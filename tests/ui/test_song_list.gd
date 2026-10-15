# Song menu: easiest chart first by ChartDifficulty (weighted taps per minute x speed); AUTOPLAY (DEV) run options.
# Related: src/core/song_catalog.gd, src/gameplay/chart/chart_difficulty.gd
extends TestCase


func _chart(taps: Array[Dictionary], end_beat: float, units_per_beat: float = 7.0) -> Dictionary:
	return {"tempo": [{"beat": 0, "bpm": 120}], "end_beat": end_beat,
			"speed": [{"beat": 0, "units_per_beat": units_per_beat}], "events": taps}


func test_score_weights_actions_and_speed() -> void:
	var jumps: Dictionary = _chart([{"beat": 4, "type": "jump"}, {"beat": 8, "type": "jump"}], 120.0)
	assert_almost_eq(ChartDifficulty.score(jumps), 2.0, 0.0001, "two jumps in one minute")
	var flips: Dictionary = _chart([{"beat": 4, "type": "flip"}, {"beat": 8, "type": "roll"}], 120.0)
	assert_almost_eq(ChartDifficulty.score(flips), 3.5, 0.0001)
	var fast: Dictionary = _chart([{"beat": 4, "type": "jump"}, {"beat": 8, "type": "camera"}], 120.0, 14.0)
	assert_almost_eq(ChartDifficulty.score(fast), 2.0, 0.0001, "double speed, camera cues ignored")
	assert_eq(ChartDifficulty.tier_name(30.0), "EASY")
	assert_eq(ChartDifficulty.tier_name(70.0), "EXPERT")


func test_song_list_is_sorted_easiest_first() -> void:
	var entries: Array[SongCatalog.Entry] = SongCatalog.list_songs()
	assert_true(entries.size() >= 2, "several songs listed")
	for index: int in range(1, entries.size()):
		assert_true(entries[index - 1].difficulty <= entries[index].difficulty, "%s before %s" % [
				entries[index - 1].title, entries[index].title])


func test_autoplay_dev_run_plays_the_chosen_chart_by_itself() -> void:
	var options: LaunchOptions = LaunchOptions.autoplay_run("res://assets/music/pulse_drive.chart.json")
	assert_true(options.autoplay)
	assert_false(options.attract_mode, "HUD, SFX and the run menu stay on")
	assert_false(options.practice)
	assert_eq(options.chart_path, "res://assets/music/pulse_drive.chart.json")
