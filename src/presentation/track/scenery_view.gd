# Procedural background: floating neon monoliths and crystal spires scattered along the track,
# kept clear of the track corridor and of the side camera's line of sight. Grouped into MultiMesh
# chunks along the track so far chunks are culled; density scales with the quality tier. Edge colors come
# from the phase palette (instance COLOR.r = brightness, COLOR.g = blend between its two scenery colors).
# Related: src/presentation/track/track_view.gd, src/presentation/shaders/neon_box.gdshader
class_name SceneryView
extends Node3D

const BOX_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const BOX_DETAIL_SHADER: Shader = preload("res://src/presentation/shaders/neon_box_detail.gdshader")
const WIRE_SHADER: Shader = preload("res://src/presentation/shaders/neon_wire.gdshader")
const SCENERY_DETAIL: Texture2D = preload("res://assets/textures/scenery_detail.png")
const SPACING: float = 8.0
const CLEAR_RADIUS: float = 16.0
## Track length covered by one MultiMesh chunk, and how far chunks stay visible (fog hides the rest).
const CHUNK_LENGTH: float = 120.0
const VISIBILITY_RANGE: float = 320.0
## Number of tint steps between the palette's two scenery colors.
const TINT_STEPS: int = 4

var _random := RandomNumberGenerator.new()


func setup(context: LevelContext, seed_value: int) -> void:
	_random.seed = seed_value
	var corridor: PackedVector3Array = _sample_corridor(context.track)
	var density: float = QualityTier.scenery_density(context.quality)
	var box_mesh := BoxMesh.new()
	var spire_mesh: ArrayMesh = ProceduralMeshes.pyramid(1.0, 1.0)
	var box_material: ShaderMaterial = _box_material(context.quality)
	var wire_material: ShaderMaterial = _wire_material()
	var chunk_start: float = context.track.start_distance
	while chunk_start < context.track.end_distance:
		var blocks: Array[Transform3D] = []
		var block_colors: Array[Color] = []
		var spires: Array[Transform3D] = []
		var distance: float = chunk_start
		while distance < minf(chunk_start + CHUNK_LENGTH, context.track.end_distance):
			# Upright frame: scenery stands on world up through loops and rolls.
			var frame: Transform3D = context.track.upright_transform_at(distance)
			for attempt: int in 2:
				# Draw every random number even when skipped, so the layout is identical on every tier.
				var placement: Transform3D = _random_block(frame)
				var tint: float = float(_random.randi() % TINT_STEPS) / float(TINT_STEPS - 1)
				var color := Color(_random.randf_range(0.5, 1.0), tint, 0.0)
				var has_spire: bool = _random.randf() < 0.35
				var kept: bool = _random.randf() < density
				if kept and _is_clear(placement.origin, placement.basis.get_scale(), corridor):
					blocks.append(placement)
					block_colors.append(color)
					if has_spire:
						spires.append(_spire_on_top(placement))
			distance += SPACING
		var spire_colors: Array[Color] = []
		spire_colors.resize(spires.size())
		spire_colors.fill(Color.WHITE)
		if not blocks.is_empty():
			add_child(_multimesh_instance("Monoliths", box_mesh, blocks, block_colors, box_material))
		if not spires.is_empty():
			add_child(_multimesh_instance("Spires", spire_mesh, spires, spire_colors, wire_material))
		chunk_start += CHUNK_LENGTH


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
	instance.visibility_range_end = VISIBILITY_RANGE
	return instance


## Lit windows (detail shader variant) only on tiers that afford detail textures.
func _box_material(quality: QualityTier.Tier) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.set_shader_parameter("palette_role", 1)
	if QualityTier.uses_detail_textures(quality):
		material.shader = BOX_DETAIL_SHADER
		material.set_shader_parameter("detail_map", SCENERY_DETAIL)
	else:
		material.shader = BOX_SHADER
	material.set_shader_parameter("edge_width", 0.18)
	material.set_shader_parameter("edge_energy", 1.6)
	material.set_shader_parameter("face_energy", 0.03)
	material.set_shader_parameter("pulse_gain", 0.6)
	return material


func _wire_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WIRE_SHADER
	material.set_shader_parameter("palette_role", 1)
	material.set_shader_parameter("edge_energy", 1.6)
	material.set_shader_parameter("face_energy", 0.1)
	return material
