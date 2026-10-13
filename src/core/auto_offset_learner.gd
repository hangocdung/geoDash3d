# Learns the audio offset from normal play: collects tap errors (tap − nearest cue, seconds, positive = late)
# and, between runs, proposes an adjustment for UserSettings.audio_offset_sec. Big consistent offsets
# (Bluetooth) are corrected fast from few taps; small ones slowly from many. Pure logic, no nodes.
# Related: src/core/calibration_math.gd, src/presentation/level/level_runner.gd, docs/roadmap.md (GD3-054)
class_name AutoOffsetLearner
extends RefCounted

## (minimum |median| sec, minimum samples, gain, maximum step sec), checked from the largest offset down.
const RULES: Array[Vector4] = [
	Vector4(0.1, 3, 0.9, 0.35),
	Vector4(0.03, 8, 0.7, 0.06),
	Vector4(0.012, 20, 0.5, 0.02),
]
## Robust spread (MAD × 1.4826) above which taps are too inconsistent to learn from.
const MAX_SPREAD_SEC: float = 0.045
const MAX_SAMPLES: int = 60
const MAD_TO_SIGMA: float = 1.4826

var _samples: PackedFloat64Array = []


func add_sample(error_sec: float) -> void:
	if is_nan(error_sec):
		return
	_samples.append(error_sec)
	if _samples.size() > MAX_SAMPLES:
		_samples.remove_at(0)


func sample_count() -> int:
	return _samples.size()


## Offset change (seconds) to add to the audio offset, or 0 when the evidence is not strong enough.
func compute_adjustment() -> float:
	if _samples.size() < 3:
		return 0.0
	var center: float = _median(_samples)
	var deviations: PackedFloat64Array = []
	for sample: float in _samples:
		deviations.append(absf(sample - center))
	if _median(deviations) * MAD_TO_SIGMA > MAX_SPREAD_SEC:
		return 0.0
	for rule: Vector4 in RULES:
		if absf(center) >= rule.x and _samples.size() >= int(rule.y):
			return clampf(center * rule.z, -rule.w, rule.w)
	return 0.0


## After the offset changed by `adjustment_sec`, stored errors shrink by the same amount.
func shift(adjustment_sec: float) -> void:
	for index: int in _samples.size():
		_samples[index] -= adjustment_sec


func clear() -> void:
	_samples.clear()


static func _median(values: PackedFloat64Array) -> float:
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	var middle: int = sorted.size() >> 1
	return sorted[middle] if sorted.size() % 2 == 1 else (sorted[middle - 1] + sorted[middle]) * 0.5
