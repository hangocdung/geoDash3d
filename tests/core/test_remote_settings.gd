# Remote Config tuning: typed after the defaults, bad values keep the default, gameplay reads it once per level
# (window scale clamped), and the defaults match the designed GameplayConfig. Related: src/core/remote_settings.gd
extends TestCase


func after_each() -> void:
	RemoteSettings.reset()


func test_defaults_match_the_designed_config() -> void:
	var designed := GameplayConfig.new()
	assert_eq(RemoteSettings.get_int("shield_combo"), designed.shield_combo)
	var played: GameplayConfig = GameplayConfig.create_for_play()
	assert_almost_eq(played.perfect_window_sec, designed.perfect_window_sec, 0.000001)


func test_values_are_typed_after_the_defaults() -> void:
	RemoteSettings.load_json('{"unlock_free_songs": "4", "unlock_progress": "0.7", "rewarded_trials": "false", "x": "1"}')
	assert_eq(RemoteSettings.get_int("unlock_free_songs"), 4)
	assert_almost_eq(RemoteSettings.get_float("unlock_progress"), 0.7, 0.000001)
	assert_false(RemoteSettings.get_bool("rewarded_trials"))


func test_bad_values_keep_the_default() -> void:
	expect_errors(2)
	RemoteSettings.load_json('{"shield_combo": "many", "rewarded_trials": "yes"}')
	assert_eq(RemoteSettings.get_int("shield_combo"), 16)
	assert_true(RemoteSettings.get_bool("rewarded_trials"))


func test_play_config_applies_tuning_with_a_clamped_window_scale() -> void:
	RemoteSettings.load_json('{"shield_combo": "12", "timing_window_scale": "3.0"}')
	var designed := GameplayConfig.new()
	var played: GameplayConfig = GameplayConfig.create_for_play()
	assert_eq(played.shield_combo, 12)
	assert_almost_eq(played.great_window_sec, designed.great_window_sec * RemoteSettings.WINDOW_SCALE_RANGE.y, 0.000001,
			"3.0 is clamped to the top of the range")
