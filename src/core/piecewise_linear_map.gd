# Monotonic piecewise-linear mapping y(x) built from keys x_i with constant rates r_i (dy/dx > 0).
# Used for beat→time (TempoMap) and beat→distance (speed changes). Extrapolates with edge rates.
# Related: src/core/tempo_map.gd, src/gameplay/chart/level_chart.gd
class_name PiecewiseLinearMap
extends RefCounted

var _keys: PackedFloat64Array = []
var _values: PackedFloat64Array = []
var _rates: PackedFloat64Array = []


## Returns null (with an error) when keys are not strictly increasing or a rate is not positive.
static func build(keys: PackedFloat64Array, rates: PackedFloat64Array,
		value_at_first_key: float) -> PiecewiseLinearMap:
	if keys.is_empty() or keys.size() != rates.size():
		push_error("PiecewiseLinearMap: keys (%d) and rates (%d) must be non-empty and equal in size"
				% [keys.size(), rates.size()])
		return null
	for index: int in keys.size():
		if rates[index] <= 0.0:
			push_error("PiecewiseLinearMap: rate at key %f must be > 0 (got %f)" % [keys[index], rates[index]])
			return null
		if index > 0 and keys[index] <= keys[index - 1]:
			push_error("PiecewiseLinearMap: keys must be strictly increasing (%f after %f)"
					% [keys[index], keys[index - 1]])
			return null
	var result := PiecewiseLinearMap.new()
	result._keys = keys.duplicate()
	result._rates = rates.duplicate()
	result._values.resize(keys.size())
	result._values[0] = value_at_first_key
	for index: int in range(1, keys.size()):
		var span: float = keys[index] - keys[index - 1]
		result._values[index] = result._values[index - 1] + span * rates[index - 1]
	return result


func map(x: float) -> float:
	var index: int = _segment_for_key(x)
	return _values[index] + (x - _keys[index]) * _rates[index]


func inverse(y: float) -> float:
	var index: int = _segment_for_value(y)
	return _keys[index] + (y - _values[index]) / _rates[index]


func rate_at(x: float) -> float:
	return _rates[_segment_for_key(x)]


func key_count() -> int:
	return _keys.size()


## Index of the last key <= x (0 when x is before the first key).
func _segment_for_key(x: float) -> int:
	return _last_index_not_greater(_keys, x)


func _segment_for_value(y: float) -> int:
	return _last_index_not_greater(_values, y)


static func _last_index_not_greater(sorted_values: PackedFloat64Array, query: float) -> int:
	var low: int = 0
	var high: int = sorted_values.size() - 1
	if query <= sorted_values[0]:
		return 0
	while low < high:
		var middle: int = (low + high + 1) >> 1
		if sorted_values[middle] <= query:
			low = middle
		else:
			high = middle - 1
	return low
