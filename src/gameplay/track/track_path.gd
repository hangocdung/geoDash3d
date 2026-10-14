# Track geometry as a function of distance: dense frame table built by integrating the chart's
# track segments (straight / turn / slope). Frame axes: X = forward, Y = up, Z = right-hand side.
# Related: src/gameplay/chart/level_chart.gd, src/presentation/track/track_view.gd
class_name TrackPath
extends RefCounted

const SAMPLE_SPACING: float = 0.5
## Extra track generated before beat 0 (count-in) and after the end (outro).
const LEAD_IN_BEATS: float = 16.0
const LEAD_OUT_BEATS: float = 24.0

var start_distance: float = 0.0
var end_distance: float = 0.0
var _positions: PackedVector3Array = []
var _yaws: PackedFloat32Array = []
var _pitches: PackedFloat32Array = []


## `min_end_beat`: build at least this far (the end of the song, so a short chart's outro still has road).
static func build(chart: LevelChart, min_end_beat: float = -INF) -> TrackPath:
	var path := TrackPath.new()
	var last_beat: float = maxf(chart.end_beat + LEAD_OUT_BEATS, min_end_beat)
	path.start_distance = chart.distance_at(-LEAD_IN_BEATS)
	path.end_distance = chart.distance_at(last_beat)
	var ranges: Array[Vector2] = []
	for index: int in chart.track_segments.size():
		var segment_start: float = chart.distance_at(chart.track_segments[index].beat)
		var next_beat: float = chart.track_segments[index + 1].beat if index + 1 < chart.track_segments.size() \
				else last_beat
		ranges.append(Vector2(segment_start, chart.distance_at(next_beat)))
	path._integrate(chart.track_segments, ranges)
	return path


func sample_count() -> int:
	return _positions.size()


func transform_at(distance: float) -> Transform3D:
	var index_float: float = (distance - start_distance) / SAMPLE_SPACING
	var last: int = _positions.size() - 1
	if index_float <= 0.0:
		return _extrapolate(0, index_float * SAMPLE_SPACING)
	if index_float >= float(last):
		return _extrapolate(last, (index_float - float(last)) * SAMPLE_SPACING)
	var index: int = int(index_float)
	var weight: float = index_float - float(index)
	var position: Vector3 = _positions[index].lerp(_positions[index + 1], weight)
	var yaw: float = lerp_angle(_yaws[index], _yaws[index + 1], weight)
	var pitch: float = lerpf(_pitches[index], _pitches[index + 1], weight)
	return Transform3D(frame_basis(yaw, pitch), position)


static func frame_basis(yaw: float, pitch: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch)


func _extrapolate(index: int, extra_distance: float) -> Transform3D:
	var basis: Basis = frame_basis(_yaws[index], _pitches[index])
	return Transform3D(basis, _positions[index] + basis.x * extra_distance)


func _integrate(segments: Array[ChartItems.TrackSegment], ranges: Array[Vector2]) -> void:
	var count: int = int(ceil((end_distance - start_distance) / SAMPLE_SPACING)) + 1
	_positions.resize(count)
	_yaws.resize(count)
	_pitches.resize(count)
	var yaw: float = 0.0
	# The track passes through the origin at distance 0 along +X before any turn.
	var position := Vector3(start_distance, 0.0, 0.0)
	var segment_index: int = -1
	for sample: int in count:
		var distance: float = start_distance + float(sample) * SAMPLE_SPACING
		while segment_index + 1 < segments.size() and ranges[segment_index + 1].x <= distance:
			segment_index += 1
		var slope_rate: float = 0.0
		if segment_index >= 0:
			var segment: ChartItems.TrackSegment = segments[segment_index]
			var span: Vector2 = ranges[segment_index]
			slope_rate = _slope_derivative(segment, span, distance)
		_positions[sample] = position
		_yaws[sample] = yaw
		_pitches[sample] = atan(slope_rate)
		# Step to the next sample using the derivatives at the midpoint for accuracy.
		var mid_distance: float = distance + SAMPLE_SPACING * 0.5
		var mid_yaw: float = yaw + _yaw_rate(segments, ranges, segment_index) * SAMPLE_SPACING * 0.5
		var mid_slope: float = 0.0
		if segment_index >= 0:
			mid_slope = _slope_derivative(segments[segment_index], ranges[segment_index], mid_distance)
		position += Vector3(cos(mid_yaw), 0.0, -sin(mid_yaw)) * SAMPLE_SPACING + Vector3.UP * mid_slope * SAMPLE_SPACING
		yaw += _yaw_rate(segments, ranges, segment_index) * SAMPLE_SPACING


static func _yaw_rate(segments: Array[ChartItems.TrackSegment], ranges: Array[Vector2],
		segment_index: int) -> float:
	if segment_index < 0:
		return 0.0
	var segment: ChartItems.TrackSegment = segments[segment_index]
	if segment.shape != ChartItems.TrackSegment.Shape.TURN:
		return 0.0
	var length: float = ranges[segment_index].y - ranges[segment_index].x
	return deg_to_rad(segment.angle_deg) / maxf(length, SAMPLE_SPACING)


## Height derivative dh/ds of a smoothstep slope at `distance` (0 outside slopes).
static func _slope_derivative(segment: ChartItems.TrackSegment, span: Vector2, distance: float) -> float:
	if segment.shape != ChartItems.TrackSegment.Shape.SLOPE:
		return 0.0
	var length: float = maxf(span.y - span.x, SAMPLE_SPACING)
	var t: float = clampf((distance - span.x) / length, 0.0, 1.0)
	return segment.rise * 6.0 * t * (1.0 - t) / length
