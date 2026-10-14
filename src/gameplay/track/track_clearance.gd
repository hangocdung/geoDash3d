# Spatial queries on a built TrackPath: does the track run into itself (helices, loops: checked by tests on
# every shipped chart) and is the column under a point free of track (support pillars). Samples are bucketed
# in a coarse grid so both queries stay cheap on long tracks.
# Related: track_path.gd, src/presentation/track/track_view.gd (pillars), tests/gameplay/test_track_shapes.gd
class_name TrackClearance
extends RefCounted

const CELL_SIZE: float = 8.0
## Every n-th path sample is indexed (1 unit apart).
const SAMPLE_STRIDE: int = 2
## Track this close along the path is the same stretch, not an overlap.
const MIN_PATH_SEPARATION: float = 30.0

var _path: TrackPath
var _cells: Dictionary[Vector3i, PackedInt32Array] = {}
var _columns: Dictionary[Vector2i, PackedInt32Array] = {}


func _init(path: TrackPath) -> void:
	_path = path
	for index: int in range(0, path.sample_count(), SAMPLE_STRIDE):
		var position: Vector3 = path.sample_position(index)
		var cell := Vector3i((position / CELL_SIZE).floor())
		if not _cells.has(cell):
			_cells[cell] = PackedInt32Array()
		_cells[cell].append(index)
		var column := Vector2i(cell.x, cell.z)
		if not _columns.has(column):
			_columns[column] = PackedInt32Array()
		_columns[column].append(index)


## Distance of the first place where another stretch of track enters the room above or below the road
## (TrackPath.CLEARANCE_ABOVE / CLEARANCE_BELOW, `half_width` + 1 to each side), or NAN if there is none.
func find_self_overlap(half_width: float) -> float:
	var reach: int = int(ceil((TrackPath.CLEARANCE_ABOVE + half_width) / CELL_SIZE))
	for index: int in range(0, _path.sample_count(), SAMPLE_STRIDE):
		var distance: float = _path.sample_distance(index)
		var frame: Transform3D = _path.transform_at(distance)
		var inverse: Basis = frame.basis.inverse()
		var cell := Vector3i((frame.origin / CELL_SIZE).floor())
		for x: int in range(-reach, reach + 1):
			for y: int in range(-reach, reach + 1):
				for z: int in range(-reach, reach + 1):
					var others: PackedInt32Array = _cells.get(cell + Vector3i(x, y, z), PackedInt32Array())
					for other: int in others:
						if absf(_path.sample_distance(other) - distance) < MIN_PATH_SEPARATION:
							continue
						var local: Vector3 = inverse * (_path.sample_position(other) - frame.origin)
						if absf(local.x) < 1.0 and absf(local.z) < half_width + 1.0 \
								and local.y > -TrackPath.CLEARANCE_BELOW and local.y < TrackPath.CLEARANCE_ABOVE:
							return distance
	return NAN


## True when no track passes under `point` within `radius` (horizontally) and `depth` below it.
func is_column_clear(point: Vector3, radius: float, depth: float) -> bool:
	var reach: int = int(ceil(radius / CELL_SIZE))
	var center := Vector2i(int(floor(point.x / CELL_SIZE)), int(floor(point.z / CELL_SIZE)))
	for x: int in range(-reach, reach + 1):
		for z: int in range(-reach, reach + 1):
			for index: int in _columns.get(center + Vector2i(x, z), PackedInt32Array()):
				var position: Vector3 = _path.sample_position(index)
				var below: float = point.y - position.y
				if below > 1.0 and below < depth and Vector2(position.x - point.x, position.z - point.z).length() < radius:
					return false
	return true
