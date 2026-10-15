# Flight corridor (gameplay v4): glowing gold plates at the floor and ceiling heights of every corridor bucket with
# spikes on them, as four MultiMeshes (four draw calls however long the corridor). Spikes rise in a wave a few beats
# ahead of the player, snapped to sixteenth notes, animated in corridor_spike.gdshader (no per-frame CPU work).
# LOW draws one wide spike per step instead of three. Related: src/gameplay/simulation/flight_corridor.gd
class_name CorridorView
extends Node3D

const SPIKE_SHADER: Shader = preload("res://src/presentation/shaders/corridor_spike.gdshader")
const PLATE_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const PLATE_THICKNESS: float = 0.22
const SPIKE_HEIGHT: float = 0.85
## Spikes start rising this many beats before the player reaches them.
const RISE_LEAD_BEATS: float = 3.0
const RISE_GRID_BEATS: float = 0.25


func build(context: LevelContext) -> void:
	var flight: FlightCorridor = context.chart.flight
	if flight == null:
		return
	var rich: bool = QualityTier.uses_rich_hazards(context.quality)
	var width: float = context.config.track_width + 0.4
	var lanes: PackedFloat32Array = [-1.0, 0.0, 1.0] if rich else [0.0]
	var spike_base: float = width / float(lanes.size()) * 0.85
	var plates: Array[Transform3D] = []
	var floor_spikes: Array[Transform3D] = []
	var ceiling_spikes: Array[Transform3D] = []
	var floor_beats: PackedFloat32Array = []
	var ceiling_beats: PackedFloat32Array = []
	for section: int in flight.starts.size():
		for local: int in flight.counts[section]:
			var index: int = flight.offsets[section] + local
			var distance: float = flight.starts[section] + (float(local) + 0.5) * flight.bucket_length
			var frame: Transform3D = context.track.transform_at(distance)
			var beat: float = context.chart.beat_at_distance(distance)
			var rise_beat: float = floorf((beat - RISE_LEAD_BEATS) / RISE_GRID_BEATS) * RISE_GRID_BEATS
			var plate_scale := Basis().scaled(Vector3(flight.bucket_length, PLATE_THICKNESS, width))
			var ceiling: float = flight.ceilings[index]
			plates.append(frame * Transform3D(plate_scale, Vector3(0, ceiling + PLATE_THICKNESS * 0.5, 0)))
			for lane: float in lanes:
				ceiling_spikes.append(frame * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, ceiling, lane)))
				ceiling_beats.append(rise_beat)
			var floor_height: float = flight.floors[index]
			if floor_height <= FlightCorridor.NO_FLOOR:
				continue
			plates.append(frame * Transform3D(plate_scale, Vector3(0, floor_height - PLATE_THICKNESS * 0.5, 0)))
			for lane: float in lanes:
				floor_spikes.append(frame * Transform3D(Basis(), Vector3(0, floor_height, lane)))
				floor_beats.append(rise_beat)
	var spike_mesh: ArrayMesh = ProceduralMeshes.pyramid(spike_base, SPIKE_HEIGHT)
	var spike_material: ShaderMaterial = _spike_material(rich)
	add_child(_multimesh(spike_mesh, spike_material, floor_spikes, floor_beats))
	add_child(_multimesh(spike_mesh, spike_material, ceiling_spikes, ceiling_beats))
	var plate_mesh := BoxMesh.new()
	add_child(_multimesh(plate_mesh, _plate_material(), plates, PackedFloat32Array()))


static func _spike_material(rich: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SPIKE_SHADER
	material.set_shader_parameter("edge_color", GameplayConfig.FLY_COLOR)
	material.set_shader_parameter("entrance_style", 1 if rich else 0)
	material.set_shader_parameter("flash_gain", 0.35 if UserSettings.reduce_flashing else 1.0)
	return material


static func _plate_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PLATE_SHADER
	material.set_shader_parameter("edge_color", GameplayConfig.FLY_COLOR)
	material.set_shader_parameter("edge_energy", 1.2)
	material.set_shader_parameter("edge_width", 0.05)
	material.set_shader_parameter("face_energy", 0.04)
	return material


## One MultiMesh instance; `rise_beats` (when given) goes to INSTANCE_CUSTOM.x for the spike shader.
static func _multimesh(mesh: Mesh, material: Material, transforms: Array[Transform3D],
		rise_beats: PackedFloat32Array) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = not rise_beats.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
		if multimesh.use_custom_data:
			multimesh.set_instance_custom_data(index, Color(rise_beats[index], 0.0, 0.0, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
