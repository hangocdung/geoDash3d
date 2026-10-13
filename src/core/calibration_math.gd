# Pure math for audio calibration: tap error against the nearest beat and a robust offset estimate
# (median-based outlier rejection). Positive offset = the player hears audio later than the engine.
# Related: src/ui/calibration/calibration_screen.gd, src/core/user_settings.gd
class_name CalibrationMath
extends RefCounted

const MIN_SAMPLES: int = 8
## Taps farther than this many robust deviations from the median are ignored.
const OUTLIER_DEVIATIONS: float = 3.0
const MIN_OUTLIER_LIMIT_SEC: float = 0.025
const MAD_TO_SIGMA: float = 1.4826


class Estimate:
	var offset_sec: float = 0.0
	## Standard deviation of the accepted taps (how consistent the player was).
	var spread_sec: float = 0.0
	var accepted_count: int = 0
	var is_valid: bool = false


## Signed seconds between a tap and the nearest whole beat (positive = late).
static func tap_error(tap_time_sec: float, tempo: TempoMap) -> float:
	var nearest_beat: float = roundf(tempo.time_to_beat(tap_time_sec))
	return tap_time_sec - tempo.beat_to_time(nearest_beat)


static func estimate(errors: PackedFloat64Array) -> Estimate:
	var result := Estimate.new()
	if errors.size() < MIN_SAMPLES:
		return result
	var center: float = _median(errors)
	var deviations: PackedFloat64Array = []
	for error: float in errors:
		deviations.append(absf(error - center))
	var limit: float = maxf(_median(deviations) * MAD_TO_SIGMA * OUTLIER_DEVIATIONS, MIN_OUTLIER_LIMIT_SEC)
	var accepted: PackedFloat64Array = []
	for error: float in errors:
		if absf(error - center) <= limit:
			accepted.append(error)
	result.accepted_count = accepted.size()
	if accepted.size() < MIN_SAMPLES:
		return result
	var total: float = 0.0
	for error: float in accepted:
		total += error
	result.offset_sec = total / accepted.size()
	var variance: float = 0.0
	for error: float in accepted:
		variance += (error - result.offset_sec) * (error - result.offset_sec)
	result.spread_sec = sqrt(variance / accepted.size())
	result.is_valid = true
	return result


static func _median(values: PackedFloat64Array) -> float:
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	var middle: int = sorted.size() >> 1
	if sorted.size() % 2 == 1:
		return sorted[middle]
	return (sorted[middle - 1] + sorted[middle]) * 0.5
