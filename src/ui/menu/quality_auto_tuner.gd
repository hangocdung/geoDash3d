# Benchmarks the menu's attract run and steps the graphics tier down (HIGH → MEDIUM → LOW) until the
# average FPS reaches the target; the result is saved to UserSettings. Only runs when quality_auto is on,
# and only ever lowers quality, so it cannot oscillate. Related: main_menu.gd, src/core/quality_tier.gd
class_name QualityAutoTuner
extends Node

const WARMUP_SEC: float = 3.0
const SAMPLE_SEC: float = 4.0
const TARGET_FPS: float = 55.0

var _level: LevelRunner
var _elapsed: float = 0.0
var _frames: int = 0
var _done: bool = false


func setup(level: LevelRunner) -> void:
	_level = level
	_done = not UserSettings.quality_auto


func _process(delta: float) -> void:
	if _done or _level == null:
		return
	_elapsed += delta
	if _elapsed < WARMUP_SEC:
		return
	_frames += 1
	if _elapsed < WARMUP_SEC + SAMPLE_SEC:
		return
	var fps: float = _frames / SAMPLE_SEC
	var tier: QualityTier.Tier = UserSettings.quality_tier
	print("QUALITY auto: %.1f FPS at %s" % [fps, QualityTier.Tier.keys()[tier]])
	if fps >= TARGET_FPS or tier == QualityTier.Tier.LOW:
		_finish()
		return
	var lower: QualityTier.Tier = QualityTier.from_int(int(tier) - 1)
	UserSettings.quality_tier = lower
	_level.apply_quality(lower)
	_elapsed = 0.0
	_frames = 0


func _finish() -> void:
	_done = true
	UserSettings.save_settings()
