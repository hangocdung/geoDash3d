# Builds the model-based obstacles (GD3-104): laser fence, pendulum axe, spiked mine, crusher, two-lane laser
# wall and ring gate, from the Blender models in assets/models (materials Body / Glow, shared per color). The
# part that moves with the beat is the child named ObstacleFactory.MOVING_PART (posed by ObstacleView).
# Related: obstacle_factory.gd, obstacle_view.gd, assets/blender/generate_models.py
class_name ObstacleModels
extends RefCounted

const LASER_POST: PackedScene = preload("res://assets/models/laser_post.glb")
const PENDULUM_FRAME: PackedScene = preload("res://assets/models/pendulum_frame.glb")
const PENDULUM_BLADE: PackedScene = preload("res://assets/models/pendulum_blade.glb")
const SPIKE_MINE: PackedScene = preload("res://assets/models/spike_mine.glb")
const CRUSHER: PackedScene = preload("res://assets/models/crusher.glb")
const RING_GATE: PackedScene = preload("res://assets/models/ring_gate.glb")
const GLOW_SHADER: Shader = preload("res://src/presentation/shaders/neon_glow.gdshader")
const BOX_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const BARRIER_SHADER: Shader = preload("res://src/presentation/shaders/energy_barrier.gdshader")
## Must match generate_models.py: laser lens heights, pendulum pivot, ring center.
const LASER_BEAM_HEIGHTS: Array[float] = [0.25, 0.55]
const PENDULUM_PIVOT: float = 4.2
const RING_CENTER_HEIGHT: float = 2.2
const RING_FIELD_SIZE: float = 4.1
## The mine is drawn larger than its hitbox (like spikes) so it reads from the side camera.
const MINE_SCALE: float = 1.5
const BEAM_THICKNESS: float = 0.07
const WALL_BEAMS: int = 5
const WALL_POST_SIZE: float = 0.3
## Crusher teeth stop this far above the hitbox bottom at the low point of each pump.
const CRUSHER_MARGIN: float = 0.05
const GLOW_ENERGY: float = 4.0
const BEAM_ENERGY: float = 6.0
const BEAM_PULSE_GAIN: float = 2.0

var _cache: MaterialCache
var _body := StandardMaterial3D.new()


func _init(cache: MaterialCache) -> void:
	_cache = cache
	_body.albedo_color = Color(0.035, 0.03, 0.08)
	_body.metallic = 0.7
	_body.roughness = 0.28


static func handles(visual: HazardDefinition.Visual) -> bool:
	return visual in [HazardDefinition.Visual.LASER, HazardDefinition.Visual.PENDULUM, HazardDefinition.Visual.MINE,
			HazardDefinition.Visual.CRUSHER, HazardDefinition.Visual.LASER_WALL, HazardDefinition.Visual.RING_GATE]


func build(root: Node3D, hazard: HazardDefinition) -> void:
	match hazard.visual:
		HazardDefinition.Visual.LASER:
			for side: float in [-1.0, 1.0]:
				var post: Node3D = _model(LASER_POST, hazard.color)
				post.position = Vector3(0.0, 0.0, side * hazard.visual_width * 0.5)
				root.add_child(post)
			for height: float in LASER_BEAM_HEIGHTS:
				root.add_child(_beam(hazard, Vector3(0.0, height, 0.0), hazard.visual_width))
		HazardDefinition.Visual.PENDULUM:
			root.add_child(_model(PENDULUM_FRAME, hazard.color))
			var blade: Node3D = _model(PENDULUM_BLADE, hazard.color)
			blade.name = ObstacleFactory.MOVING_PART
			blade.position = Vector3(0.0, PENDULUM_PIVOT, 0.0)
			root.add_child(blade)
		HazardDefinition.Visual.MINE:
			var mine: Node3D = _model(SPIKE_MINE, hazard.color)
			mine.name = ObstacleFactory.MOVING_PART
			mine.position = Vector3(0.0, hazard.visual_height, hazard.lateral_center)
			mine.scale = Vector3.ONE * MINE_SCALE
			root.add_child(mine)
		HazardDefinition.Visual.CRUSHER:
			var press: Node3D = _model(CRUSHER, hazard.color)
			press.name = ObstacleFactory.MOVING_PART
			press.position = Vector3(0.0, hazard.bottom + CRUSHER_MARGIN, 0.0)
			root.add_child(press)
		HazardDefinition.Visual.LASER_WALL:
			_build_laser_wall(root, hazard)
		HazardDefinition.Visual.RING_GATE:
			var ring: Node3D = _model(RING_GATE, hazard.color)
			ring.name = ObstacleFactory.MOVING_PART
			ring.position = Vector3(0.0, RING_CENTER_HEIGHT, 0.0)
			root.add_child(ring)
			root.add_child(_field(hazard, Vector2(RING_FIELD_SIZE, RING_FIELD_SIZE), Vector3(0.0, RING_CENTER_HEIGHT, 0.0),
					true))


## Pose of the moving part at `beat` (pure function of the beat; `hazard_beat` = when the player passes).
static func pose_moving_part(part: Node3D, hazard: HazardDefinition, hazard_beat: float, beat: float) -> void:
	match hazard.visual:
		HazardDefinition.Visual.PENDULUM:
			# Swings along the track, hanging straight down (over its hitbox) whenever the player arrives.
			part.rotation.z = deg_to_rad(55.0) * sin(PI * (beat - hazard_beat))
		HazardDefinition.Visual.MINE:
			part.position.y = hazard.visual_height + 0.1 * sin(beat * PI)
			part.rotation.y = beat * 0.25 * TAU
		HazardDefinition.Visual.CRUSHER:
			# Slams down to its lowest point on every beat, then winds back up.
			var phase: float = beat - floorf(beat)
			part.position.y = hazard.bottom + CRUSHER_MARGIN + 0.55 * (1.0 - exp(-phase * 5.0))
		HazardDefinition.Visual.RING_GATE:
			part.rotation.x = beat * 0.125 * TAU


## Laser grid over the two covered lanes: end posts, horizontal beams and a faint field behind them.
func _build_laser_wall(root: Node3D, hazard: HazardDefinition) -> void:
	var post_material: ShaderMaterial = _cache.get_material(StringName("laser_post_%s" % hazard.id), BOX_SHADER,
			{"edge_color": hazard.color, "edge_energy": 4.5, "edge_width": 0.05, "proximity_gain": 1.0})
	for side: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.mesh = BoxMesh.new()
		post.material_override = post_material
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		post.transform = Transform3D(Basis().scaled(Vector3(WALL_POST_SIZE, hazard.visual_height, WALL_POST_SIZE)),
				Vector3(0.0, hazard.visual_height * 0.5, hazard.lateral_center + side * hazard.visual_width * 0.5))
		root.add_child(post)
	for index: int in WALL_BEAMS:
		var height: float = lerpf(0.35, hazard.visual_height - 0.2, float(index) / float(WALL_BEAMS - 1))
		root.add_child(_beam(hazard, Vector3(0.0, height, hazard.lateral_center), hazard.visual_width))
	root.add_child(_field(hazard, Vector2(hazard.visual_width, hazard.visual_height),
			Vector3(0.0, hazard.visual_height * 0.5, hazard.lateral_center), false))


func _beam(hazard: HazardDefinition, center: Vector3, width: float) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	beam.mesh = BoxMesh.new()
	beam.material_override = _cache.get_material(StringName("beam_%s" % hazard.color.to_html()), GLOW_SHADER,
			{"glow_color": hazard.color, "energy": BEAM_ENERGY, "pulse_gain": BEAM_PULSE_GAIN})
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.transform = Transform3D(Basis().scaled(Vector3(BEAM_THICKNESS, BEAM_THICKNESS, width)), center)
	return beam


## Energy field facing the player (`circular` for the ring gate).
func _field(hazard: HazardDefinition, size: Vector2, center: Vector3, circular: bool) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var field := MeshInstance3D.new()
	field.mesh = quad
	field.material_override = _cache.get_material(StringName("field_%s_%s" % [hazard.id, circular]), BARRIER_SHADER,
			{"wall_color": hazard.color, "circular": circular, "energy": 1.6 if circular else 1.2})
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# QuadMesh faces +Z; turn it to span the track width (Z) and stand up (Y).
	field.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), center)
	return field


func _model(scene: PackedScene, color: Color) -> Node3D:
	var glow: ShaderMaterial = _cache.get_material(StringName("model_glow_%s" % color.to_html()), GLOW_SHADER,
			{"glow_color": color, "energy": GLOW_ENERGY})
	return NeonModel.instantiate_with(scene, {"Body": _body, "Glow": glow, "GlowAlt": glow})
