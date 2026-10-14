# Floor profile along the track: piecewise-constant ground height by distance (0 = road surface),
# with gaps where there is no ground at all. Built from the chart's "terrain" entries (placed by beat).
# Related: src/gameplay/chart/level_chart.gd, src/gameplay/simulation/run_simulation.gd
class_name Terrain
extends RefCounted

## Height reported where there is no ground (a gap).
const GAP: float = -INF
const FIRST_START: float = -1.0e18

## Start distance of each piece; piece i covers [_starts[i], _starts[i + 1]).
var _starts: PackedFloat64Array = [FIRST_START]
var _heights: PackedFloat64Array = [0.0]


## `starts` must be sorted ascending; ground before the first start is at height 0.
static func build(starts: PackedFloat64Array, heights: PackedFloat64Array) -> Terrain:
	var terrain := Terrain.new()
	for index: int in starts.size():
		terrain._starts.append(starts[index])
		terrain._heights.append(heights[index])
	return terrain


static func is_gap(height: float) -> bool:
	return is_inf(height) and height < 0.0


func is_flat() -> bool:
	for height: float in _heights:
		if height != 0.0:
			return false
	return true


## Highest ground under the span [from_distance, to_distance], or GAP if there is none at all.
func support_height(from_distance: float, to_distance: float) -> float:
	var index: int = maxi(_starts.bsearch(from_distance, false) - 1, 0)
	var best: float = GAP
	while index < _starts.size() and _starts[index] <= to_distance:
		best = maxf(best, _heights[index])
		index += 1
	return best


func height_at(distance: float) -> float:
	return support_height(distance, distance)


## Height for visuals: gaps report the ground height just before them (or 0).
func surface_height_at(distance: float) -> float:
	var index: int = maxi(_starts.bsearch(distance, false) - 1, 0)
	while index > 0 and is_gap(_heights[index]):
		index -= 1
	return 0.0 if is_gap(_heights[index]) else _heights[index]


## True when every piece touching [from_distance, to_distance] is ground at exactly `height`.
func is_level(from_distance: float, to_distance: float, height: float) -> bool:
	var index: int = maxi(_starts.bsearch(from_distance, false) - 1, 0)
	while index < _starts.size() and _starts[index] <= to_distance:
		if _heights[index] != height:
			return false
		index += 1
	return true


## Exact average ground height over [distance - radius, distance + radius] (gaps count as the ground
## before them). Continuous in `distance`, so a camera can follow it without steps.
func smoothed_height_at(distance: float, radius: float) -> float:
	var from_distance: float = distance - radius
	var to_distance: float = distance + radius
	if radius <= 0.0:
		return surface_height_at(distance)
	var index: int = maxi(_starts.bsearch(from_distance, false) - 1, 0)
	var fallback: float = surface_height_at(from_distance)
	var total: float = 0.0
	while index < _starts.size() and _starts[index] < to_distance:
		var height: float = _heights[index]
		if is_gap(height):
			height = fallback
		else:
			fallback = height
		total += height * (minf(piece_end(index), to_distance) - maxf(_starts[index], from_distance))
		index += 1
	return total / (to_distance - from_distance)


func piece_count() -> int:
	return _starts.size()


func piece_start(index: int) -> float:
	return _starts[index]


## End distance of piece `index` (INF for the last one).
func piece_end(index: int) -> float:
	return _starts[index + 1] if index + 1 < _starts.size() else INF


func piece_height(index: int) -> float:
	return _heights[index]
