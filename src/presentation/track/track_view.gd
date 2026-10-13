# Builds the visible road from TrackPath in chunks (for frustum culling) plus support pillars
# that drop into the fog. Purely visual; collision lives in RunSimulation.
# Related: src/presentation/meshes/procedural_meshes.gd, src/presentation/shaders/neon_track.gdshader
class_name TrackView
extends Node3D

const TRACK_SHADER: Shader = preload("res://src/presentation/shaders/neon_track.gdshader")
const BOX_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const CHUNK_LENGTH: float = 48.0
const PILLAR_SPACING: float = 42.0
const PILLAR_DEPTH: float = 60.0
## Clear space under the track so the player can run on the underside (flip).
const UNDERSIDE_CLEARANCE: float = 2.8

var track_material: ShaderMaterial


func setup(context: LevelContext) -> void:
	var width: float = context.config.track_width
	var thickness: float = context.config.track_thickness
	track_material = ShaderMaterial.new()
	track_material.shader = TRACK_SHADER
	var distance: float = context.track.start_distance
	while distance < context.track.end_distance:
		var chunk_end: float = minf(distance + CHUNK_LENGTH, context.track.end_distance)
		var chunk := MeshInstance3D.new()
		chunk.name = "TrackChunk%d" % get_child_count()
		chunk.mesh = ProceduralMeshes.track_chunk(context.track, distance, chunk_end, width, thickness)
		chunk.material_override = track_material
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chunk)
		distance = chunk_end
	_build_pillars(context, width, thickness)


func _build_pillars(context: LevelContext, width: float, thickness: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = BOX_SHADER
	material.set_shader_parameter("edge_color", Color(0.55, 0.35, 1.0))
	material.set_shader_parameter("edge_energy", 2.5)
	material.set_shader_parameter("edge_width", 0.1)
	var transforms: Array[Transform3D] = []
	var distance: float = context.track.start_distance + PILLAR_SPACING * 0.5
	while distance < context.track.end_distance:
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
