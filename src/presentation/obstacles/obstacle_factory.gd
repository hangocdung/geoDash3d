# Builds obstacle visuals (crystal spike, two-lane wall, energy gate), jump pads and cue markers (timing
# ring, floating action icon, lit lane strip for dodges, floating ring for jump orbs). Visual only; sizes
# come from HazardDefinition / GameplayConfig.
# Related: obstacle_view.gd, material_cache.gd, src/presentation/shaders/glyph.gdshader
class_name ObstacleFactory
extends RefCounted

const WIRE_SHADER: Shader = preload("res://src/presentation/shaders/neon_wire.gdshader")
const BOX_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const BARRIER_SHADER: Shader = preload("res://src/presentation/shaders/energy_barrier.gdshader")
const GLYPH_SHADER: Shader = preload("res://src/presentation/shaders/glyph.gdshader")
const GLYPH_RING: int = 0
const GLYPH_CHEVRONS: int = 1
const GLYPH_SIDESTEP: int = 4
const GLYPH_FLIP: int = 5
const GLYPH_ORB: int = 6
const PAD_SIZE: float = 2.0
const ICON_SIZE: float = 1.3
const ICON_CLEARANCE: float = 1.3
const POST_SIZE: float = 0.35
const ORB_SIZE: float = 1.7
const PAD_WIDTH: float = 1.3
const PAD_THICKNESS: float = 0.14
## Hazards (and pads) brighten up to (1 + gain)x as the player approaches (shader proximity glow).
const APPROACH_GAIN: float = 1.0

var _cache := MaterialCache.new()
var _spike_meshes: Dictionary[StringName, Mesh] = {}


## Root origin = hazard center on the track surface; children are offset laterally as needed.
func build_hazard(hazard: HazardDefinition) -> Node3D:
	var root := Node3D.new()
	match hazard.visual:
		HazardDefinition.Visual.SPIKE:
			var spike: MeshInstance3D = _mesh_instance(_spike_mesh(hazard), _cache.get_material(
					StringName("wire_%s" % hazard.id), WIRE_SHADER, {"edge_color": hazard.color,
					"proximity_gain": APPROACH_GAIN}))
			spike.position.z = hazard.lateral_center
			root.add_child(spike)
		HazardDefinition.Visual.WALL:
			var wall: MeshInstance3D = _mesh_instance(BoxMesh.new(), _cache.get_material(StringName("wall_%s" % hazard.id),
					BOX_SHADER, {"edge_color": hazard.color, "edge_energy": 5.0, "edge_width": 0.08, "face_energy": 0.22,
					"pulse_gain": 0.6, "proximity_gain": APPROACH_GAIN}))
			wall.transform = Transform3D(Basis().scaled(Vector3(hazard.visual_length, hazard.visual_height,
					hazard.visual_width)), Vector3(0, hazard.visual_height * 0.5, hazard.lateral_center))
			root.add_child(wall)
		HazardDefinition.Visual.GATE:
			_build_gate(root, hazard)
	return root


## Ring at the tap moment (in the target lane, on the ground under the player), icon above the paired
## obstacle (none for terrain jumps, so it is never mistaken for an orb), lit strip for dodges.
## Jump orbs float where the player will be (`cue_height` = its feet at the cue).
func build_cue_markers(cue: ChartItems.ActionCue, cue_height: float,
		context: LevelContext) -> Array[GeometryInstance3D]:
	var action: ActionDefinition = cue.action
	if action.air_allowed:
		return _orb_markers(cue, cue_height, context)
	var lane: float = action.lateral_distance if action.kind == ActionDefinition.Kind.DODGE else 0.0
	var markers: Array[GeometryInstance3D] = []
	var ring: MeshInstance3D = _plane(Vector2(PAD_SIZE, PAD_SIZE), _glyph(action, GLYPH_RING, false))
	ring.transform = context.frame_at_height(cue.beat, cue_height) * Transform3D(Basis(), Vector3(0, 0.03, lane))
	markers.append(ring)
	if cue.has_hazard:
		markers.append(_icon(cue, cue_height, context, lane))
	if action.kind == ActionDefinition.Kind.DODGE:
		var strip_beats: float = action.hazard_beat_offset
		var length: float = context.chart.distance_at(cue.beat + strip_beats) - context.chart.distance_at(cue.beat)
		var strip: MeshInstance3D = _plane(Vector2(context.config.lane_width * 0.8, length),
				_glyph(action, GLYPH_CHEVRONS, false))
		# PlaneMesh is in XZ; turn it so the chevrons point along the track (+X).
		strip.transform = context.frame_at_beat(cue.beat + strip_beats * 0.5) \
				* Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0.04, lane))
		markers.append(strip)
	return markers


## Floating action icon above the obstacle paired with `cue`.
func _icon(cue: ChartItems.ActionCue, cue_height: float, context: LevelContext, lane: float) -> MeshInstance3D:
	var action: ActionDefinition = cue.action
	var hazard: HazardDefinition = context.config.find_hazard(action.paired_hazard)
	var icon := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.mesh = quad
	icon.material_override = _glyph(action, _icon_glyph(action), true)
	var icon_beat: float = cue.beat + action.hazard_beat_offset
	var icon_ground: float = maxf(cue_height, context.chart.surface_height_at(icon_beat))
	var icon_height: float = (hazard.visual_height if hazard != null else 1.0) + ICON_CLEARANCE
	icon.transform = context.frame_at_height(icon_beat, icon_ground) * Transform3D(Basis(), Vector3(0, icon_height, lane))
	return icon


## Jump pad: a glowing slab with forward chevrons (no tap icon: tapping would jump off before the pad).
func build_pad(color: Color, half_length: float) -> Node3D:
	var root := Node3D.new()
	var slab: MeshInstance3D = _mesh_instance(BoxMesh.new(), _cache.get_material(&"pad_slab", BOX_SHADER,
			{"edge_color": color, "edge_energy": 5.0, "edge_width": 0.06, "face_energy": 0.45, "pulse_gain": 1.0,
			"proximity_gain": APPROACH_GAIN}))
	slab.transform = Transform3D(Basis().scaled(Vector3(half_length * 2.0, PAD_THICKNESS, PAD_WIDTH)),
			Vector3(0, PAD_THICKNESS * 0.5, 0))
	root.add_child(slab)
	var arrows: MeshInstance3D = _plane(Vector2(PAD_WIDTH, half_length * 2.0), _cache.get_material(&"pad_arrows",
			GLYPH_SHADER, {"glyph_color": color, "glyph": GLYPH_CHEVRONS, "billboard": false, "energy": 2.6}))
	# PlaneMesh is in XZ; turn it so the chevrons point along the track (+X).
	arrows.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, PAD_THICKNESS + 0.02, 0))
	root.add_child(arrows)
	return root


## Camera-facing orb (bright core inside rings), centred on the player's body at the tap moment.
func _orb_markers(cue: ChartItems.ActionCue, cue_height: float, context: LevelContext) -> Array[GeometryInstance3D]:
	var quad := QuadMesh.new()
	quad.size = Vector2(ORB_SIZE, ORB_SIZE)
	var orb: MeshInstance3D = _mesh_instance(quad, _glyph(cue.action, GLYPH_ORB, true))
	orb.transform = context.frame_at_height(cue.beat, cue_height + GameplayConfig.CUBE_SIZE * 0.5)
	return [orb]


func _build_gate(root: Node3D, hazard: HazardDefinition) -> void:
	var post_material: ShaderMaterial = _cache.get_material(StringName("post_%s" % hazard.id), BOX_SHADER,
			{"edge_color": hazard.color, "edge_energy": 4.5, "edge_width": 0.05, "proximity_gain": APPROACH_GAIN})
	var half_width: float = hazard.visual_width * 0.5
	for side: float in [-1.0, 1.0]:
		var post: MeshInstance3D = _mesh_instance(BoxMesh.new(), post_material)
		post.transform = Transform3D(Basis().scaled(Vector3(POST_SIZE, hazard.visual_height + 0.4, POST_SIZE)),
				Vector3(0, (hazard.visual_height + 0.4) * 0.5, side * half_width))
		root.add_child(post)
	var beam: MeshInstance3D = _mesh_instance(BoxMesh.new(), post_material)
	beam.transform = Transform3D(Basis().scaled(Vector3(POST_SIZE, POST_SIZE, hazard.visual_width + POST_SIZE)),
			Vector3(0, hazard.visual_height + 0.4, 0))
	root.add_child(beam)
	var field := QuadMesh.new()
	field.size = Vector2(hazard.visual_width, hazard.visual_height)
	var plane: MeshInstance3D = _mesh_instance(field, _cache.get_material(StringName("field_%s" % hazard.id),
			BARRIER_SHADER, {"wall_color": hazard.color}))
	# QuadMesh faces +Z; turn it to span the track width (Z) and stand up (Y).
	plane.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, hazard.visual_height * 0.5, 0))
	root.add_child(plane)


func _spike_mesh(hazard: HazardDefinition) -> Mesh:
	if not _spike_meshes.has(hazard.id):
		_spike_meshes[hazard.id] = ProceduralMeshes.pyramid(hazard.visual_length, hazard.visual_height)
	return _spike_meshes[hazard.id]


func _icon_glyph(action: ActionDefinition) -> int:
	match action.kind:
		ActionDefinition.Kind.DODGE:
			return GLYPH_SIDESTEP
		ActionDefinition.Kind.FLIP:
			return GLYPH_FLIP
	return GLYPH_CHEVRONS


func _glyph(action: ActionDefinition, glyph: int, billboard: bool) -> ShaderMaterial:
	return _cache.get_material(StringName("glyph_%s_%d" % [action.id, glyph]), GLYPH_SHADER,
			{"glyph_color": action.color, "glyph": glyph, "billboard": billboard, "energy": 2.2})


func _plane(size: Vector2, material: Material) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	return _mesh_instance(plane, material)


static func _mesh_instance(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
