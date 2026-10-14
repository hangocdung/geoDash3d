# Track geometry as a function of distance: dense frame table built by integrating the chart's track
# segments (straight / turn / slope / helix / loop / roll / wave, turns optionally banked). Frames are stored
# as quaternions so loops and rolls interpolate cleanly. Frame axes: X = forward, Y = up, Z = right-hand side.
# Gameplay never reads it (collision lives in track space); presentation places everything with it.
# Related: src/gameplay/chart/level_chart.gd, src/presentation/track/track_view.gd, track_clearance.gd
class_name TrackPath
extends RefCounted

const SAMPLE_SPACING: float = 0.5
## Extra track generated before beat 0 (count-in) and after the end (outro).
const LEAD_IN_BEATS: float = 16.0
const LEAD_OUT_BEATS: float = 24.0
## Fraction of a helix / loop over which its climb / pitch rate eases in and out (no kink at either end).
const HELIX_EASE: float = 0.15
const LOOP_EASE: float = 0.2
## Fraction of a banked turn over which the bank leans in and out.
const BANK_EASE: float = 0.3
## Room a stretch of track needs above its road (terrain, pads, big orbs, the cube) and below it (flips run
## under the road): another stretch of track may not pass through it. Helices must climb at least
## CLEARANCE_ABOVE + CLEARANCE_BELOW per revolution.
const CLEARANCE_ABOVE: float = 12.0
const CLEARANCE_BELOW: float = 4.5

var start_distance: float = 0.0
var end_distance: float = 0.0
var _positions: PackedVector3Array = []
var _rotations: Array[Quaternion] = []
## Heading (yaw around world up) per sample: loops and rolls do not change it.
var _yaws: PackedFloat32Array = []


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


func sample_position(index: int) -> Vector3:
	return _positions[index]


func sample_distance(index: int) -> float:
	return start_distance + float(index) * SAMPLE_SPACING


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
	return Transform3D(Basis(_rotations[index].slerp(_rotations[index + 1], weight)), position)


## Track position at `distance` in an upright frame that only follows the heading (world up stays up through
## loops and rolls): for scenery placed around the track.
func upright_transform_at(distance: float) -> Transform3D:
	var index: int = clampi(int((distance - start_distance) / SAMPLE_SPACING), 0, _yaws.size() - 1)
	return Transform3D(Basis(Vector3.UP, _yaws[index]), transform_at(distance).origin)


## True where the road's up axis is close to world up (no loop, roll, steep bank or slope).
func is_upright_at(distance: float, min_up: float = 0.97) -> bool:
	return transform_at(distance).basis.y.y >= min_up


static func frame_basis(yaw: float, pitch: float, roll: float = 0.0) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch) * Basis(Vector3.RIGHT, roll)


func _extrapolate(index: int, extra_distance: float) -> Transform3D:
	var basis := Basis(_rotations[index])
	return Transform3D(basis, _positions[index] + basis.x * extra_distance)


func _integrate(segments: Array[ChartItems.TrackSegment], ranges: Array[Vector2]) -> void:
	var count: int = int(ceil((end_distance - start_distance) / SAMPLE_SPACING)) + 1
	_positions.resize(count)
	_rotations.resize(count)
	_yaws.resize(count)
	var yaw: float = 0.0
	# The track passes through the origin at distance 0 along +X before any turn.
	var position := Vector3(start_distance, 0.0, 0.0)
	var segment_index: int = -1
	for sample: int in count:
		var distance: float = start_distance + float(sample) * SAMPLE_SPACING
		while segment_index + 1 < segments.size() and ranges[segment_index + 1].x <= distance:
			segment_index += 1
		var state: Vector4 = _shape_state(segments, ranges, segment_index, distance)
		_positions[sample] = position
		_yaws[sample] = yaw
		_rotations[sample] = frame_basis(yaw, atan(state.x) + state.y, state.z).get_rotation_quaternion()
		# Step to the next sample using the derivatives at the midpoint for accuracy.
		var yaw_rate: float = _yaw_rate(segments, ranges, segment_index)
		var mid_yaw: float = yaw + yaw_rate * SAMPLE_SPACING * 0.5
		var mid_state: Vector4 = _shape_state(segments, ranges, segment_index, distance + SAMPLE_SPACING * 0.5)
		position += _step_direction(segments, segment_index, mid_yaw, mid_state) * SAMPLE_SPACING
		yaw += yaw_rate * SAMPLE_SPACING


## Direction of travel per unit of track distance. Height profiles (slope, helix, wave) climb on top of a
## horizontal unit step (their rise is exact); loops follow the true arc in their vertical plane.
static func _step_direction(segments: Array[ChartItems.TrackSegment], segment_index: int, yaw: float,
		state: Vector4) -> Vector3:
	var heading := Vector3(cos(yaw), 0.0, -sin(yaw))
	var right := Vector3(sin(yaw), 0.0, cos(yaw))
	if segment_index >= 0 and segments[segment_index].shape == ChartItems.TrackSegment.Shape.LOOP:
		return heading * cos(state.y) + Vector3.UP * sin(state.y) + right * state.w
	return heading + Vector3.UP * state.x + right * state.w


static func _yaw_rate(segments: Array[ChartItems.TrackSegment], ranges: Array[Vector2],
		segment_index: int) -> float:
	if segment_index < 0:
		return 0.0
	var segment: ChartItems.TrackSegment = segments[segment_index]
	if segment.shape != ChartItems.TrackSegment.Shape.TURN and segment.shape != ChartItems.TrackSegment.Shape.HELIX:
		return 0.0
	var length: float = ranges[segment_index].y - ranges[segment_index].x
	return deg_to_rad(segment.angle_deg) / maxf(length, SAMPLE_SPACING)


## Shape state at `distance`: x = climb dh/ds, y = loop pitch (radians), z = roll (radians),
## w = sideways drift per unit (loops shift aside so they never run into themselves).
static func _shape_state(segments: Array[ChartItems.TrackSegment], ranges: Array[Vector2], segment_index: int,
		distance: float) -> Vector4:
	if segment_index < 0:
		return Vector4.ZERO
	var segment: ChartItems.TrackSegment = segments[segment_index]
	var span: Vector2 = ranges[segment_index]
	var length: float = maxf(span.y - span.x, SAMPLE_SPACING)
	var t: float = clampf((distance - span.x) / length, 0.0, 1.0)
	match segment.shape:
		ChartItems.TrackSegment.Shape.SLOPE:
			return Vector4(segment.rise * 6.0 * t * (1.0 - t) / length, 0.0, 0.0, 0.0)
		ChartItems.TrackSegment.Shape.HELIX:
			return Vector4(segment.rise * _ease_rate(t, HELIX_EASE) / length, 0.0, 0.0, 0.0)
		ChartItems.TrackSegment.Shape.WAVE:
			var climb: float = segment.amplitude * PI * float(segment.count) * sin(TAU * float(segment.count) * t)
			return Vector4(climb / length, 0.0, 0.0, 0.0)
		ChartItems.TrackSegment.Shape.LOOP:
			return Vector4(0.0, TAU * _ease_amount(t, LOOP_EASE), 0.0, segment.lateral * 6.0 * t * (1.0 - t) / length)
		ChartItems.TrackSegment.Shape.ROLL:
			return Vector4(0.0, 0.0, deg_to_rad(segment.roll_deg) * smoothstep(0.0, 1.0, t), 0.0)
		ChartItems.TrackSegment.Shape.TURN:
			if segment.bank_deg != 0.0:
				var lean: float = smoothstep(0.0, BANK_EASE, t) * smoothstep(0.0, BANK_EASE, 1.0 - t)
				# Lean into the turn: a left turn (positive angle) lifts the right-hand side.
				return Vector4(0.0, 0.0, -signf(segment.angle_deg) * deg_to_rad(segment.bank_deg) * lean, 0.0)
	return Vector4.ZERO


## Rate profile with eased ends whose integral over 0..1 is 1.
static func _ease_rate(t: float, ease: float) -> float:
	return smoothstep(0.0, ease, t) * smoothstep(0.0, ease, 1.0 - t) / (1.0 - ease)


## Integral of _ease_rate from 0 to t (0 → 1, symmetric).
static func _ease_amount(t: float, ease: float) -> float:
	var area: float = 1.0 - ease
	if t < ease:
		return ease * _ramp_integral(t / ease) / area
	if t > 1.0 - ease:
		return 1.0 - ease * _ramp_integral((1.0 - t) / ease) / area
	return (ease * 0.5 + t - ease) / area


## Integral of smoothstep(0, 1, x) from 0 to x.
static func _ramp_integral(x: float) -> float:
	return x * x * x - 0.5 * x * x * x * x
