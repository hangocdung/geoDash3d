# Spawns hazard visuals (crystal spikes, energy barriers) and ground cue pads that tell the
# player which action the next tap performs. Flashes pads when cues are judged.
# Related: src/gameplay/chart/level_chart.gd, src/presentation/shaders/glyph.gdshader
class_name ObstacleView
extends Node3D

const WIRE_SHADER: Shader = preload("res://src/presentation/shaders/neon_wire.gdshader")
const BARRIER_SHADER: Shader = preload("res://src/presentation/shaders/energy_barrier.gdshader")
const GLYPH_SHADER: Shader = preload("res://src/presentation/shaders/glyph.gdshader")
const BOX_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const VISIBILITY_RANGE: float = 240.0
const PAD_SIZE: float = 2.2
const ICON_SIZE: float = 1.3
const GLYPH_RING: int = 0
const GLYPH_CHEVRONS: int = 1
const GLYPH_ARROWS: int = 2
const FLASH_DECAY_PER_SEC: float = 4.0

## Per cue: ground timing ring and floating action icon (same index as chart.cues).
var _cue_pads: Array[GeometryInstance3D] = []
var _cue_icons: Array[GeometryInstance3D] = []
var _pad_flash: PackedFloat32Array = []
var _materials: Dictionary[StringName, ShaderMaterial] = {}


func setup(context: LevelContext) -> void:
	var spike_meshes: Dictionary[StringName, Mesh] = {}
	for placement: ChartItems.HazardPlacement in context.chart.hazards:
		var frame: Transform3D = context.track.transform_at(placement.distance)
		match placement.hazard.id:
			&"barrier":
				_add_barrier(frame, placement.hazard)
			_:
				if not spike_meshes.has(placement.hazard.id):
					spike_meshes[placement.hazard.id] = ProceduralMeshes.pyramid(
							placement.hazard.visual_length, placement.hazard.visual_height)
				_add_spike(frame, placement.hazard, spike_meshes[placement.hazard.id])
	for cue: ChartItems.ActionCue in context.chart.cues:
		_add_cue_marker(context, cue)
	_pad_flash.resize(_cue_pads.size())
	_pad_flash.fill(0.0)


func flash_cue(cue_index: int, strength: float) -> void:
	if cue_index >= 0 and cue_index < _pad_flash.size():
		_pad_flash[cue_index] = maxf(_pad_flash[cue_index], strength)


func reset_view() -> void:
	_pad_flash.fill(0.0)
	for index: int in _cue_pads.size():
		_cue_pads[index].set_instance_shader_parameter("flash", 0.0)
		_cue_icons[index].set_instance_shader_parameter("flash", 0.0)


func _process(delta: float) -> void:
	for index: int in _pad_flash.size():
		if _pad_flash[index] <= 0.0:
			continue
		_pad_flash[index] = maxf(_pad_flash[index] - delta * FLASH_DECAY_PER_SEC, 0.0)
		_cue_pads[index].set_instance_shader_parameter("flash", _pad_flash[index])
		_cue_icons[index].set_instance_shader_parameter("flash", _pad_flash[index])


func _add_spike(frame: Transform3D, hazard: HazardDefinition, mesh: Mesh) -> void:
	var spike := MeshInstance3D.new()
	spike.mesh = mesh
	spike.material_override = _wire_material(hazard)
	spike.transform = frame
	_finish_instance(spike)


func _add_barrier(frame: Transform3D, hazard: HazardDefinition) -> void:
	var width: float = TrackView.TRACK_WIDTH + 0.6
	var wall := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, hazard.visual_height)
	wall.mesh = quad
	wall.material_override = _barrier_material(hazard)
	# QuadMesh faces +Z; turn it so it spans the track width (frame Z) and stands up (frame Y).
	wall.transform = frame * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, hazard.visual_height * 0.5, 0))
	_finish_instance(wall)
	for side: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post.mesh = post_mesh
		post.material_override = _post_material(hazard)
		post.transform = frame * Transform3D(Basis().scaled(Vector3(0.35, hazard.visual_height + 0.4, 0.35)),
				Vector3(0, (hazard.visual_height + 0.4) * 0.5, side * width * 0.5))
		_finish_instance(post)


func _add_cue_marker(context: LevelContext, cue: ChartItems.ActionCue) -> void:
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(PAD_SIZE, PAD_SIZE)
	ring.mesh = plane
	ring.material_override = _glyph_material(cue.action, GLYPH_RING, false)
	ring.transform = context.frame_at_beat(cue.beat) * Transform3D(Basis(), Vector3(0, 0.03, 0))
	_finish_instance(ring)
	_cue_pads.append(ring)

	# Camera-facing icon floating above where the obstacle sits: "^" = jump, ">>" = dash.
	var icon := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.mesh = quad
	var glyph: int = GLYPH_ARROWS if cue.action.id == &"dash" else GLYPH_CHEVRONS
	icon.material_override = _glyph_material(cue.action, glyph, true)
	var hazard: HazardDefinition = context.config.find_hazard(cue.action.paired_hazard)
	var icon_height: float = (hazard.visual_height if hazard != null else 1.0) + 1.3
	icon.transform = context.frame_at_beat(cue.beat + cue.action.hazard_beat_offset) 			* Transform3D(Basis(), Vector3(0, icon_height, 0))
	_finish_instance(icon)
	_cue_icons.append(icon)


func _finish_instance(instance: GeometryInstance3D) -> void:
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = VISIBILITY_RANGE
	add_child(instance)


func _wire_material(hazard: HazardDefinition) -> ShaderMaterial:
	return _cached(StringName("wire_%s" % hazard.id), WIRE_SHADER, {"edge_color": hazard.color})


func _barrier_material(hazard: HazardDefinition) -> ShaderMaterial:
	return _cached(StringName("barrier_%s" % hazard.id), BARRIER_SHADER, {"wall_color": hazard.color})


func _post_material(hazard: HazardDefinition) -> ShaderMaterial:
	return _cached(StringName("post_%s" % hazard.id), BOX_SHADER,
			{"edge_color": hazard.color, "edge_energy": 4.0, "edge_width": 0.05})


func _glyph_material(action: ActionDefinition, glyph: int, billboard: bool) -> ShaderMaterial:
	return _cached(StringName("glyph_%s_%d" % [action.id, glyph]), GLYPH_SHADER,
			{"glyph_color": action.color, "glyph": glyph, "billboard": billboard, "energy": 2.2})


func _cached(key: StringName, shader: Shader, parameters: Dictionary) -> ShaderMaterial:
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = shader
	for parameter_name: String in parameters:
		material.set_shader_parameter(parameter_name, parameters[parameter_name])
	_materials[key] = material
	return material
