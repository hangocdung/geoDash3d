# Builds obstacle visuals (crystal spikes, saw blade, spiked ceiling, two-lane wall, energy gate; model-based
# ones in obstacle_models.gd), jump pads
# and cue markers (timing ring, floating action icon, lit lane strip for dodges, floating rings for jump /
# big / dive orbs). Visual only; sizes come from HazardDefinition / GameplayConfig.
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
const GLYPH_DIVE_ORB: int = 7
const GLYPH_BIG_ORB: int = 8
## Name of the child ObstacleView moves with the beat (saw blade, pendulum axe, mine, crusher, ring).
const MOVING_PART: StringName = &"MovingPart"
const BIG_ORB_SCALE: float = 1.3
const CEILING_SLAB: float = 0.4
const CEILING_SPIKE_SPACING: float = 0.8
const PAD_SIZE: float = 2.0
const ICON_SIZE: float = 1.3
const ICON_CLEARANCE: float = 1.3
const POST_SIZE: float = 0.35
const ORB_SIZE: float = 1.7
const PAD_WIDTH: float = 1.3
const PAD_THICKNESS: float = 0.14
## Hazards (and pads) brighten up to (1 + gain)x as the player approaches (shader proximity glow).
const APPROACH_GAIN: float = 1.0
## Tap markers: the quad is this much bigger than the glyph so an approach ring can shrink onto it during the
## last `CUE_APPROACH_BEATS` before the tap; markers pulse harder with the beat than other glyphs.
const CUE_APPROACH_SCALE: float = 2.2
const CUE_APPROACH_BEATS: float = 2.0
const CUE_BEAT_GAIN: float = 1.8

var _cache := MaterialCache.new()
var _models := ObstacleModels.new(_cache)
var _spike_meshes: Dictionary[StringName, Mesh] = {}


## Root origin = hazard center on the track surface; children are offset laterally as needed.
func build_hazard(hazard: HazardDefinition) -> Node3D:
	var root := Node3D.new()
	if ObstacleModels.handles(hazard.visual):
		_models.build(root, hazard)
		return root
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
		HazardDefinition.Visual.SAW:
			_build_saw(root, hazard)
		HazardDefinition.Visual.CEILING:
			_build_ceiling(root, hazard)
	return root


## Ring at the tap moment (in the target lane, on the ground under the player), icon above the paired
## obstacle (none for terrain jumps, so it is never mistaken for an orb), lit strip for dodges. Ring and icon
## hang under the track where the player or the obstacle is there (underside runs).
## Jump orbs float where the player will be (`cue_height` = its feet at the cue).
func build_cue_markers(cue: ChartItems.ActionCue, cue_height: float,
		context: LevelContext) -> Array[GeometryInstance3D]:
	var action: ActionDefinition = cue.action
	if action.air_allowed:
		return _orb_markers(cue, cue_height, context)
	var lane: float = action.lateral_distance if action.kind == ActionDefinition.Kind.DODGE else 0.0
	var markers: Array[GeometryInstance3D] = []
	var ring: MeshInstance3D = _plane(Vector2(PAD_SIZE, PAD_SIZE) * CUE_APPROACH_SCALE, _cue_glyph(action,
			GLYPH_RING, false, 0.42))
	var ring_frame: Transform3D = context.underside_frame_at(cue.beat) if context.chart.is_cue_underside(cue) \
			else context.frame_at_height(cue.beat, cue_height)
	ring.transform = ring_frame * Transform3D(Basis(), Vector3(0, 0.03, lane))
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
	var icon_frame: Transform3D = context.frame_at_height(icon_beat, icon_ground)
	if hazard != null and context.chart.is_hazard_underside(hazard, icon_beat):
		icon_frame = context.underside_frame_at(icon_beat)
	icon.transform = icon_frame * Transform3D(Basis(), Vector3(0, icon_height, lane))
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
	var glyph: int = GLYPH_ORB
	var size: float = ORB_SIZE
	if cue.action.dive_speed > 0.0:
		glyph = GLYPH_DIVE_ORB
	elif cue.action.jump_height > context.config.find_action(context.config.default_action).jump_height:
		glyph = GLYPH_BIG_ORB
		size *= BIG_ORB_SCALE
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size) * CUE_APPROACH_SCALE
	var orb: MeshInstance3D = _mesh_instance(quad, _cue_glyph(cue.action, glyph, true, 0.47))
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


## Blade on a hub, half sunk into the road; the blade is the spinner child.
func _build_saw(root: Node3D, hazard: HazardDefinition) -> void:
	var radius: float = hazard.visual_length * 0.5
	var blade: MeshInstance3D = _mesh_instance(ProceduralMeshes.saw_blade(radius, radius * 0.7, 8,
			hazard.visual_width), _cache.get_material(StringName("saw_%s" % hazard.id), WIRE_SHADER,
			{"edge_color": hazard.color, "face_energy": 0.15, "proximity_gain": APPROACH_GAIN}))
	blade.name = MOVING_PART
	blade.position = Vector3(0, hazard.visual_height - radius, hazard.lateral_center)
	root.add_child(blade)


## Spiked slab over the whole road: a glowing slab with rows of down-pointing spikes under it.
func _build_ceiling(root: Node3D, hazard: HazardDefinition) -> void:
	var slab_bottom: float = hazard.visual_height - CEILING_SLAB
	var slab: MeshInstance3D = _mesh_instance(BoxMesh.new(), _cache.get_material(StringName("slab_%s" % hazard.id),
			BOX_SHADER, {"edge_color": hazard.color, "edge_energy": 5.0, "edge_width": 0.06, "face_energy": 0.3,
			"pulse_gain": 0.6, "proximity_gain": APPROACH_GAIN}))
	slab.transform = Transform3D(Basis().scaled(Vector3(hazard.visual_length, CEILING_SLAB, hazard.visual_width)),
			Vector3(0, slab_bottom + CEILING_SLAB * 0.5, 0))
	root.add_child(slab)
	var count: int = maxi(1, int(round(hazard.visual_length / CEILING_SPIKE_SPACING)))
	var spike_height: float = slab_bottom - hazard.bottom + 0.1
	var mesh: Mesh = ProceduralMeshes.pyramid_row(hazard.visual_length, spike_height, count)
	var material: ShaderMaterial = _cache.get_material(StringName("wire_%s" % hazard.id), WIRE_SHADER,
			{"edge_color": hazard.color, "proximity_gain": APPROACH_GAIN})
	var rows: int = 3
	for row: int in rows:
		var spikes: MeshInstance3D = _mesh_instance(mesh, material)
		var lateral: float = (float(row) - float(rows - 1) * 0.5) * hazard.visual_width / float(rows)
		# Upside down: the row hangs from the slab with its tips pointing at the road.
		spikes.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, slab_bottom, lateral))
		root.add_child(spikes)


func _spike_mesh(hazard: HazardDefinition) -> Mesh:
	if not _spike_meshes.has(hazard.id):
		_spike_meshes[hazard.id] = ProceduralMeshes.pyramid_row(hazard.visual_length, hazard.visual_height,
				maxi(hazard.repeat, 1))
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


## Tap marker glyph: approach ring landing on `target_radius` (glyph space) on the cue beat (instance uniform
## `cue_beat`, set by ObstacleView), stronger beat pulse.
func _cue_glyph(action: ActionDefinition, glyph: int, billboard: bool, target_radius: float) -> ShaderMaterial:
	return _cache.get_material(StringName("cue_%s_%d" % [action.id, glyph]), GLYPH_SHADER,
			{"glyph_color": action.color, "glyph": glyph, "billboard": billboard, "energy": 2.2,
			"approach_scale": CUE_APPROACH_SCALE, "approach_beats": CUE_APPROACH_BEATS,
			"approach_target": target_radius, "beat_gain": CUE_BEAT_GAIN})


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
