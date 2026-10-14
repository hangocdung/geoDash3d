# Builds the visible road from TrackPath in chunks (for frustum culling), cut open where the terrain has
# gaps, plus raised ground blocks (same neon road look, lit step faces) and support pillars that drop into
# the fog. Purely visual; collision lives in RunSimulation.
# Related: src/presentation/meshes/procedural_meshes.gd, src/gameplay/track/terrain.gd, neon_track.gdshader
class_name TrackView
extends Node3D

const TRACK_SHADER: Shader = preload("res://src/presentation/shaders/neon_track.gdshader")
const BOX_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const CHUNK_LENGTH: float = 48.0
const PILLAR_SPACING: float = 42.0
const PILLAR_DEPTH: float = 60.0
## Pillars keep this far from the edges of a gap.
const PILLAR_GAP_CLEARANCE: float = 2.0
## Clear space under the track so the player can run on the underside (flip).
const UNDERSIDE_CLEARANCE: float = 2.8
## Raised ground: slightly brighter body and a cooler rail than the road, so steps read against it.
const BLOCK_BASE_COLOR: Color = Color(0.05, 0.045, 0.12)
const BLOCK_RAIL_COLOR: Color = Color(0.45, 0.75, 1.0)

var track_material: ShaderMaterial
var block_material: ShaderMaterial


func setup(context: LevelContext) -> void:
	var width: float = context.config.track_width
	var thickness: float = context.config.track_thickness
	track_material = ShaderMaterial.new()
	track_material.shader = TRACK_SHADER
	block_material = ShaderMaterial.new()
	block_material.shader = TRACK_SHADER
	block_material.set_shader_parameter("base_color", BLOCK_BASE_COLOR)
	block_material.set_shader_parameter("rail_color", BLOCK_RAIL_COLOR)
	block_material.set_shader_parameter("grid_energy", 0.8)
	var terrain: Terrain = context.chart.terrain
	for stretch: Vector2 in _road_stretches(terrain, context.track.start_distance, context.track.end_distance):
		_build_road(context, stretch, width, thickness)
	_build_blocks(context, terrain, width)
	_build_pillars(context, terrain, width, thickness)


## Solid road between gaps, as (from, to) distances.
func _road_stretches(terrain: Terrain, start_distance: float, end_distance: float) -> Array[Vector2]:
	var stretches: Array[Vector2] = []
	var stretch_start: float = start_distance
	for index: int in terrain.piece_count():
		if not Terrain.is_gap(terrain.piece_height(index)):
			continue
		var gap_start: float = maxf(terrain.piece_start(index), start_distance)
		var gap_end: float = minf(terrain.piece_end(index), end_distance)
		if gap_start > stretch_start:
			stretches.append(Vector2(stretch_start, gap_start))
		stretch_start = maxf(stretch_start, gap_end)
	if stretch_start < end_distance:
		stretches.append(Vector2(stretch_start, end_distance))
	return stretches


func _build_road(context: LevelContext, stretch: Vector2, width: float, thickness: float) -> void:
	var distance: float = stretch.x
	while distance < stretch.y:
		var chunk_end: float = minf(distance + CHUNK_LENGTH, stretch.y)
		# Cap the faces that border a gap (not the far ends of the whole track).
		var cap_start: bool = is_equal_approx(distance, stretch.x) and stretch.x > context.track.start_distance
		var cap_end: bool = is_equal_approx(chunk_end, stretch.y) and stretch.y < context.track.end_distance
		_add_mesh("TrackChunk", ProceduralMeshes.track_chunk(context.track, distance, chunk_end, width, thickness,
				0.0, cap_start, cap_end), track_material)
		distance = chunk_end


## One mesh per raised piece, standing on the road; faces toward lower neighbours are closed.
func _build_blocks(context: LevelContext, terrain: Terrain, width: float) -> void:
	for index: int in terrain.piece_count():
		var height: float = terrain.piece_height(index)
		if Terrain.is_gap(height) or height <= 0.0:
			continue
		var from_distance: float = maxf(terrain.piece_start(index), context.track.start_distance)
		var to_distance: float = minf(terrain.piece_end(index), context.track.end_distance)
		if to_distance <= from_distance:
			continue
		var cap_start: bool = index == 0 or terrain.piece_height(index - 1) < height
		var cap_end: bool = index + 1 >= terrain.piece_count() or terrain.piece_height(index + 1) < height
		_add_mesh("Block", ProceduralMeshes.track_chunk(context.track, from_distance, to_distance, width, height,
				height, cap_start, cap_end), block_material)


func _add_mesh(node_name: String, mesh: ArrayMesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "%s%d" % [node_name, get_child_count()]
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_pillars(context: LevelContext, terrain: Terrain, width: float, thickness: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = BOX_SHADER
	material.set_shader_parameter("edge_color", Color(0.55, 0.35, 1.0))
	material.set_shader_parameter("edge_energy", 2.5)
	material.set_shader_parameter("edge_width", 0.1)
	var transforms: Array[Transform3D] = []
	var distance: float = context.track.start_distance + PILLAR_SPACING * 0.5
	while distance < context.track.end_distance:
		if not Terrain.is_gap(terrain.support_height(distance - PILLAR_GAP_CLEARANCE, distance + PILLAR_GAP_CLEARANCE)) \
				and terrain.is_level(distance - PILLAR_GAP_CLEARANCE, distance + PILLAR_GAP_CLEARANCE,
				terrain.height_at(distance)):
			var frame: Transform3D = context.track.transform_at(distance)
			var center: Vector3 = frame.origin - Vector3.UP * (thickness + UNDERSIDE_CLEARANCE + PILLAR_DEPTH * 0.5)
			var basis := Basis(Vector3.UP, atan2(-frame.basis.x.z, frame.basis.x.x)).scaled(
					Vector3(1.4, PILLAR_DEPTH, width * 0.7))
			transforms.append(Transform3D(basis, center))
		distance += PILLAR_SPACING
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var cube := BoxMesh.new()
	multimesh.mesh = cube
	multimesh.instance_count = transforms.size()
	for index: int in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		multimesh.set_instance_color(index, Color.WHITE)
	var pillars := MultiMeshInstance3D.new()
	pillars.name = "Pillars"
	pillars.multimesh = multimesh
	pillars.material_override = material
	pillars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pillars)
