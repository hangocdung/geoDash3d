# Glue between a level session and AutoOffsetLearner: collects tap timing from each simulation and,
# between runs only, folds a learned correction into UserSettings.audio_offset_sec (GD3-054).
# Related: src/core/auto_offset_learner.gd, src/presentation/level/level_runner.gd
class_name SyncLearning
extends RefCounted

var _learner := AutoOffsetLearner.new()
var _active: bool


## `active` is false for autoplay, attract, capture and slowed practice, where taps say nothing about sync.
func _init(active: bool) -> void:
	_active = active


func bind(simulation: RunSimulation) -> void:
	if _active:
		simulation.tap_timed.connect(_learner.add_sample)


## Applies a learned correction; returns a short HUD note ("" when nothing changed).
func apply_between_runs() -> String:
	if not _active or not UserSettings.auto_offset:
		return ""
	var adjustment: float = _learner.compute_adjustment()
	if absf(adjustment) < 0.001:
		return ""
	var before: float = UserSettings.audio_offset_sec
	UserSettings.audio_offset_sec = before + adjustment
	UserSettings.save_settings()
	var applied: float = UserSettings.audio_offset_sec - before
	Telemetry.log_event("calibration_done", {"offset_ms": roundi(UserSettings.audio_offset_sec * 1000.0),
			"method": "auto"})
	_learner.shift(applied)
	print("SYNC auto offset %+d ms (now %+d ms, %d taps)" % [roundi(applied * 1000.0),
			roundi(UserSettings.audio_offset_sec * 1000.0), _learner.sample_count()])
	return Locale.t("SYNC %+d ms") % roundi(applied * 1000.0)
