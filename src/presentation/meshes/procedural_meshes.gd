# Procedural meshes for the neon look: track chunks and raised ground (extruded along TrackPath, with
# optional end caps) and crystal pyramids with barycentric vertex colors for edge glow. Winding is fixed
# automatically.
# Related: src/presentation/track/track_view.gd, src/presentation/shaders/neon_wire.gdshader
class_name ProceduralMeshes
extends RefCounted

const BARY_A: Color = Color(1, 0, 0)
const BARY_B: Color = Color(0, 1, 0)
const BARY_C: Color = Color(0, 0, 1)
const TOP_FACE: Color = Color(1, 0, 0)
const SIDE_FACE: Color = Color(0, 0, 0)
const CAP_FACE: Color = Color(0, 1, 0)


## Square pyramid (spike). Origin at the base center, apex at +Y.
static func pyramid(base_size: float, height: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half: float = base_size * 0.5
	var apex := Vector3(0.0, height, 0.0)
	var corners: Array[Vector3] = [
		Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half),
	]
	for index: int in 4:
		var a: Vector3 = corners[index]
		var b: Vector3 = corners[(index + 1) % 4]
		var outward: Vector3 = ((a + b) * 0.5).normalized()
		_add_triangle(tool, [apex, a, b], [BARY_A, BARY_B, BARY_C], outward)
	tool.generate_normals()
	return tool.commit()


## Box-section road between two distances, its top `lift` above the track. Top face: UV.x across,
## UV.y distance; sides and caps: UV.x down from the top edge. Caps close the start/end faces.
static func track_chunk(track: TrackPath, from_distance: float, to_distance: float, width: float,
		thickness: float, lift: float = 0.0, cap_start: bool = false, cap_end: bool = false) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_width: float = width * 0.5
	var steps: int = maxi(1, int(ceil((to_distance - from_distance) / TrackPath.SAMPLE_SPACING)))
	var previous: Transform3D = track.transform_at(from_distance)
	var previous_distance: float = from_distance
	for step: int in range(1, steps + 1):
		var distance: float = minf(from_distance + float(step) * TrackPath.SAMPLE_SPACING, to_distance)
		var current: Transform3D = track.transform_at(distance)
		var near_left: Vector3 = previous * Vector3(0, lift, -half_width)
		var near_right: Vector3 = previous * Vector3(0, lift, half_width)
		var far_left: Vector3 = current * Vector3(0, lift, -half_width)
		var far_right: Vector3 = current * Vector3(0, lift, half_width)
		var drop_near: Vector3 = -previous.basis.y * thickness
		var drop_far: Vector3 = -current.basis.y * thickness
		var up: Vector3 = current.basis.y
		var side: Vector3 = current.basis.z
		_add_quad(tool, [near_left, far_left, far_right, near_right],
				[Vector2(0, previous_distance), Vector2(0, distance), Vector2(1, distance), Vector2(1, previous_distance)],
				TOP_FACE, up)
		_add_quad(tool, [near_right, far_right, far_right + drop_far, near_right + drop_near],
				[Vector2(0, previous_distance), Vector2(0, distance), Vector2(1, distance), Vector2(1, previous_distance)],
				SIDE_FACE, side)
		_add_quad(tool, [far_left, near_left, near_left + drop_near, far_left + drop_far],
				[Vector2(0, distance), Vector2(0, previous_distance), Vector2(1, previous_distance), Vector2(1, distance)],
				SIDE_FACE, -side)
		_add_quad(tool, [near_left + drop_near, near_right + drop_near, far_right + drop_far, far_left + drop_far],
				[Vector2(0.5, previous_distance), Vector2(0.5, previous_distance), Vector2(0.5, distance), Vector2(0.5, distance)],
				SIDE_FACE, -up)
		previous = current
		previous_distance = distance
	if cap_start:
		var start_frame: Transform3D = track.transform_at(from_distance)
		_add_cap(tool, start_frame, half_width, lift, thickness, -start_frame.basis.x)
	if cap_end:
		var end_frame: Transform3D = track.transform_at(to_distance)
		_add_cap(tool, end_frame, half_width, lift, thickness, end_frame.basis.x)
	return tool.commit()


static func _add_cap(tool: SurfaceTool, frame: Transform3D, half_width: float, lift: float, thickness: float,
		outward: Vector3) -> void:
	var top_left: Vector3 = frame * Vector3(0, lift, -half_width)
	var top_right: Vector3 = frame * Vector3(0, lift, half_width)
	var bottom_right: Vector3 = frame * Vector3(0, lift - thickness, half_width)
	var bottom_left: Vector3 = frame * Vector3(0, lift - thickness, -half_width)
	_add_quad(tool, [top_left, top_right, bottom_right, bottom_left],
			[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], CAP_FACE, outward)


static func _add_quad(tool: SurfaceTool, points: Array[Vector3], uvs: Array[Vector2], color: Color,
		normal: Vector3) -> void:
	_add_triangle_uv(tool, [points[0], points[1], points[2]], [uvs[0], uvs[1], uvs[2]], color, normal)
	_add_triangle_uv(tool, [points[0], points[2], points[3]], [uvs[0], uvs[2], uvs[3]], color, normal)


static func _add_triangle_uv(tool: SurfaceTool, points: Array[Vector3], uvs: Array[Vector2], color: Color,
		normal: Vector3) -> void:
	var order: Array[int] = _clockwise_order(points, normal)
	for index: int in order:
		tool.set_color(color)
		tool.set_normal(normal)
		tool.set_uv(uvs[index])
		tool.add_vertex(points[index])


static func _add_triangle(tool: SurfaceTool, points: Array[Vector3], colors: Array[Color], outward: Vector3) -> void:
	for index: int in _clockwise_order(points, outward):
		tool.set_color(colors[index])
		tool.add_vertex(points[index])


## Godot treats clockwise triangles (seen from the front) as front faces.
static func _clockwise_order(points: Array[Vector3], outward: Vector3) -> Array[int]:
	var face_normal: Vector3 = (points[2] - points[0]).cross(points[1] - points[0])
	if face_normal.dot(outward) >= 0.0:
		return [0, 1, 2]
	return [0, 2, 1]
