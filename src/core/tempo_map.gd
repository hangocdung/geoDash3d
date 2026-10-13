# Converts between musical beats and song time (seconds into the audio file).
# Beat 0 sits at `offset_sec`; supports tempo changes at arbitrary beats.
# Related: src/core/piecewise_linear_map.gd, src/gameplay/chart/chart_loader.gd
class_name TempoMap
extends RefCounted

const SECONDS_PER_MINUTE: float = 60.0

var offset_sec: float = 0.0
var _beat_to_time: PiecewiseLinearMap


## `beats[i]` is where `bpms[i]` starts. Returns null (with an error) on invalid data.
static func create(beats: PackedFloat64Array, bpms: PackedFloat64Array, offset: float) -> TempoMap:
	if beats.is_empty() or beats.size() != bpms.size():
		push_error("TempoMap: need the same non-zero number of beats and bpms")
		return null
	var seconds_per_beat: PackedFloat64Array = []
	for bpm: float in bpms:
		if bpm <= 0.0:
			push_error("TempoMap: bpm must be > 0 (got %f)" % bpm)
			return null
		seconds_per_beat.append(SECONDS_PER_MINUTE / bpm)
	var first_time: float = offset + beats[0] * seconds_per_beat[0]
	var mapping: PiecewiseLinearMap = PiecewiseLinearMap.build(beats, seconds_per_beat, first_time)
	if mapping == null:
		return null
	var result := TempoMap.new()
	result.offset_sec = offset
	result._beat_to_time = mapping
	return result


static func constant(bpm: float, offset: float) -> TempoMap:
	return create(PackedFloat64Array([0.0]), PackedFloat64Array([bpm]), offset)


func beat_to_time(beat: float) -> float:
	return _beat_to_time.map(beat)


func time_to_beat(time_sec: float) -> float:
	return _beat_to_time.inverse(time_sec)


func seconds_per_beat_at(beat: float) -> float:
	return _beat_to_time.rate_at(beat)


func bpm_at(beat: float) -> float:
	return SECONDS_PER_MINUTE / seconds_per_beat_at(beat)


## Signed difference in seconds between two beats (b - a).
func seconds_between(beat_a: float, beat_b: float) -> float:
	return beat_to_time(beat_b) - beat_to_time(beat_a)
