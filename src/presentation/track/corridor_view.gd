# Flight corridor (gameplay v4): glowing gold plates at the floor and ceiling heights of every corridor bucket with
# spikes on them, as three MultiMeshes (three draw calls however long the corridor). Spikes rise in a wave a few beats
# ahead of the player, snapped to sixteenth notes, animated in corridor_spike.gdshader (no per-frame CPU work).
# LOW draws one wide spike per step instead of three. The instance buffers are computed by build_data() on the
# LevelLoader thread; build() only hands them to the MultiMeshes. Related: src/gameplay/simulation/flight_corridor.gd
class_name CorridorView
extends Node3D

const SPIKE_SHADER: Shader = preload("res://src/presentation/shaders/corridor_spike.gdshader")
const PLATE_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const PLATE_THICKNESS: float = 0.22
const SPIKE_HEIGHT: float = 0.85
## Spikes start rising this many beats before the player reaches them.
const RISE_LEAD_BEATS: float = 3.0
const RISE_GRID_BEATS: float = 0.25


## MultiMesh buffers (TRANSFORM_3D rows; spikes add 4 custom floats: x = rise beat).
class Data:
	var rich: bool = true
	var spike_base: float = 1.0
	var floor_spikes: PackedFloat32Array = []
	var ceiling_spikes: PackedFloat32Array = []
	var plates: PackedFloat32Array = []


## Thread-safe (pure maths on the chart and track): every instance of the corridor, or null without a flight.
static func build_data(context: LevelContext) -> Data:
	var flight: FlightCorridor = context.chart.flight
	if flight == null:
		return null
	var data := Data.new()
	data.rich = QualityTier.uses_rich_hazards(context.quality)
	var width: float = context.config.track_width + 0.4
	var lanes: PackedFloat32Array = [-1.0, 0.0, 1.0] if data.rich else [0.0]
	data.spike_base = width / float(lanes.size()) * 0.85
	var flipped := Basis(Vector3.RIGHT, PI)
	for section: int in flight.starts.size():
		for local: int in flight.counts[section]:
			var index: int = flight.offsets[section] + local
			var distance: float = flight.starts[section] + (float(local) + 0.5) * flight.bucket_length
			var frame: Transform3D = context.track.transform_at(distance)
			var beat: float = context.chart.beat_at_distance(distance)
			var rise_beat: float = floorf((beat - RISE_LEAD_BEATS) / RISE_GRID_BEATS) * RISE_GRID_BEATS
			var plate_scale := Basis().scaled(Vector3(flight.bucket_length, PLATE_THICKNESS, width))
			var ceiling: float = flight.ceilings[index]
			_append(data.plates, frame * Transform3D(plate_scale, Vector3(0, ceiling + PLATE_THICKNESS * 0.5, 0)))
			for lane: float in lanes:
				_append(data.ceiling_spikes, frame * Transform3D(flipped, Vector3(0, ceiling, lane)), rise_beat)
			var floor_height: float = flight.floors[index]
			if floor_height <= FlightCorridor.NO_FLOOR:
				continue
			_append(data.plates, frame * Transform3D(plate_scale, Vector3(0, floor_height - PLATE_THICKNESS * 0.5, 0)))
			for lane: float in lanes:
				_append(data.floor_spikes, frame * Transform3D(Basis(), Vector3(0, floor_height, lane)), rise_beat)
	return data


## Main thread: three MultiMeshes from `data` (computed here when the loader did not).
func build(context: LevelContext, data: Data = null) -> void:
	if data == null:
		data = build_data(context)
	if data == null:
		return
	var spike_mesh: ArrayMesh = ProceduralMeshes.pyramid(data.spike_base, SPIKE_HEIGHT)
	var spike_material: ShaderMaterial = _spike_material(data.rich)
	add_child(_multimesh(spike_mesh, spike_material, data.floor_spikes, true))
	add_child(_multimesh(spike_mesh, spike_material, data.ceiling_spikes, true))
	add_child(_multimesh(BoxMesh.new(), _plate_material(), data.plates, false))


static func _append(buffer: PackedFloat32Array, transform: Transform3D, rise_beat: float = NAN) -> void:
	var basis: Basis = transform.basis
	var origin: Vector3 = transform.origin
	buffer.append_array([basis.x.x, basis.y.x, basis.z.x, origin.x, basis.x.y, basis.y.y, basis.z.y, origin.y,
			basis.x.z, basis.y.z, basis.z.z, origin.z])
	if not is_nan(rise_beat):
		buffer.append_array([rise_beat, 0.0, 0.0, 0.0])


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


## One MultiMesh instance from a packed buffer (12 floats per instance, +4 custom when `custom`).
static func _multimesh(mesh: Mesh, material: Material, buffer: PackedFloat32Array, custom: bool) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = custom
	multimesh.mesh = mesh
	multimesh.instance_count = buffer.size() / (16 if custom else 12)
	if multimesh.instance_count > 0:
		multimesh.buffer = buffer
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
