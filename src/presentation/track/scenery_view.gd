# Procedural background: floating neon monoliths and crystal spires scattered along the track,
# kept clear of the track corridor and of the side camera's line of sight. Two draw calls total.
# Related: src/presentation/track/track_view.gd, src/presentation/shaders/neon_box.gdshader
class_name SceneryView
extends Node3D

const BOX_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const WIRE_SHADER: Shader = preload("res://src/presentation/shaders/neon_wire.gdshader")
const SPACING: float = 8.0
const CLEAR_RADIUS: float = 16.0
## Cool colors only: hot pink/gold are reserved for hazards so they always stand out.
const PALETTE: Array[Color] = [
	Color(0.25, 0.75, 1.0), Color(0.45, 0.35, 1.0), Color(0.3, 0.5, 1.0), Color(0.6, 0.45, 0.95),
]

var _random := RandomNumberGenerator.new()


func setup(context: LevelContext, seed_value: int) -> void:
	_random.seed = seed_value
	var corridor: PackedVector3Array = _sample_corridor(context.track)
	var blocks: Array[Transform3D] = []
	var block_colors: Array[Color] = []
	var spires: Array[Transform3D] = []
	var distance: float = context.track.start_distance
	while distance < context.track.end_distance:
		var frame: Transform3D = context.track.transform_at(distance)
		for attempt: int in 2:
			var placement: Transform3D = _random_block(frame)
			if _is_clear(placement.origin, placement.basis.get_scale(), corridor):
				blocks.append(placement)
				block_colors.append(PALETTE[_random.randi() % PALETTE.size()] * _random.randf_range(0.5, 1.0))
				if _random.randf() < 0.35:
					spires.append(_spire_on_top(placement))
		distance += SPACING
	add_child(_multimesh_instance("Monoliths", BoxMesh.new(), blocks, block_colors, _box_material()))
	var spire_colors: Array[Color] = []
	for index: int in spires.size():
		spire_colors.append(Color.WHITE)
	add_child(_multimesh_instance("Spires", ProceduralMeshes.pyramid(1.0, 1.0), spires, spire_colors,
			_wire_material()))


func _random_block(frame: Transform3D) -> Transform3D:
	# Background side (-Z) gets most objects; camera side (+Z) only far away or deep below.
	var background: bool = _random.randf() < 0.72
	var lateral: float = -_random.randf_range(30.0, 120.0) if background else _random.randf_range(60.0, 130.0)
	var height: float = _random.randf_range(-50.0, 18.0) if background else _random.randf_range(-70.0, -24.0)
	# Tall towers only far away so they never wall off the view.
	var tall: bool = absf(lateral) > 50.0 and _random.randf() < 0.5
	var size := Vector3(_random.randf_range(3.0, 9.0), _random.randf_range(14.0, 48.0) if tall
			else _random.randf_range(2.0, 6.0), _random.randf_range(3.0, 9.0))
	var center: Vector3 = frame * Vector3(_random.randf_range(-3.0, 3.0), height, lateral)
	var yaw: float = _random.randf_range(0.0, TAU)
	return Transform3D(Basis(Vector3.UP, yaw).scaled(size), center)


func _spire_on_top(block: Transform3D) -> Transform3D:
	var size: Vector3 = block.basis.get_scale()
	var spire_height: float = _random.randf_range(3.0, 9.0)
	var top: Vector3 = block.origin + Vector3.UP * size.y * 0.5
	var spire_basis := Basis(Vector3.UP, _random.randf_range(0.0, TAU)).scaled(
			Vector3(minf(size.x, size.z) * 0.7, spire_height, minf(size.x, size.z) * 0.7))
	return Transform3D(spire_basis, top)


func _sample_corridor(track: TrackPath) -> PackedVector3Array:
	var points: PackedVector3Array = []
	var distance: float = track.start_distance
	while distance <= track.end_distance:
		points.append(track.transform_at(distance).origin)
		distance += 8.0
	return points


func _is_clear(center: Vector3, size: Vector3, corridor: PackedVector3Array) -> bool:
	var reach: float = maxf(size.x, size.z) * 0.75 + CLEAR_RADIUS
	for point: Vector3 in corridor:
		var flat := Vector2(center.x - point.x, center.z - point.z)
		var vertical_gap: float = absf(center.y - point.y) - size.y * 0.5
		if flat.length() < reach and vertical_gap < CLEAR_RADIUS:
			return false
	return true


func _multimesh_instance(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color],
		material: Material) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_color(index, colors[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _box_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BOX_SHADER
	material.set_shader_parameter("edge_color", Color.WHITE)
	material.set_shader_parameter("edge_width", 0.18)
	material.set_shader_parameter("edge_energy", 1.6)
	material.set_shader_parameter("face_energy", 0.03)
	material.set_shader_parameter("pulse_gain", 0.6)
	return material


func _wire_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WIRE_SHADER
	material.set_shader_parameter("edge_color", Color(0.45, 0.55, 1.0))
	material.set_shader_parameter("edge_energy", 1.6)
	material.set_shader_parameter("face_energy", 0.1)
	return material
