# Builds the model-based obstacles (GD3-104): laser fence, pendulum axe, spiked mine, crusher, two-lane laser
# wall, ring gate and (gameplay v4) the rolling spiked ball, from the Blender models in assets/models (one neon_model material each, shared per color;
# an obstacle is at most two draw calls, a model plus an energy field). The part that moves with the beat is the child named
# ObstacleFactory.MOVING_PART (posed by ObstacleView).
# Related: obstacle_factory.gd, obstacle_view.gd, assets/blender/generate_models.py
class_name ObstacleModels
extends RefCounted

const LASER_FENCE: PackedScene = preload("res://assets/models/laser_fence.glb")
const LASER_WALL: PackedScene = preload("res://assets/models/laser_wall.glb")
const PENDULUM_FRAME: PackedScene = preload("res://assets/models/pendulum_frame.glb")
const PENDULUM_BLADE: PackedScene = preload("res://assets/models/pendulum_blade.glb")
const SPIKE_MINE: PackedScene = preload("res://assets/models/spike_mine.glb")
const CRUSHER: PackedScene = preload("res://assets/models/crusher.glb")
const RING_GATE: PackedScene = preload("res://assets/models/ring_gate.glb")
const MACE_GANTRY: PackedScene = preload("res://assets/models/mace_gantry.glb")
const SPIKED_MACE: PackedScene = preload("res://assets/models/spiked_mace.glb")
const BARRIER_SHADER: Shader = preload("res://src/presentation/shaders/energy_barrier.gdshader")
## Must match generate_models.py: pendulum pivot, ring center, mace pivot under its gantry.
const PENDULUM_PIVOT: float = 4.2
const MACE_PIVOT: float = 6.3
## The sweeping mace swings this far either side of hanging straight down (one swing every two beats).
const MACE_SWING_DEG: float = 62.0
const RING_CENTER_HEIGHT: float = 2.2
const RING_FIELD_SIZE: float = 4.1
## The mine is drawn larger than its hitbox (like spikes) so it reads from the side camera.
const MINE_SCALE: float = 1.5
## Crusher teeth stop this far above the hitbox bottom at the low point of each pump.
const CRUSHER_MARGIN: float = 0.05
const GLOW_ENERGY: float = 4.0
## Rolling ball: model scale, radius of the drawn ball, and its speed toward the player (units per beat).
const BALL_SCALE: float = 0.6
const BALL_RADIUS: float = 0.55
const BALL_SPEED: float = 3.0
## Piston spikes: the lowest they sink between beats (share of their height).
const PISTON_LOW: float = 0.2
## Laser glow flickers harder with the beat than other model glow.
const LASER_PULSE_GAIN: float = 2.0

var _cache: MaterialCache
## Model materials by color and beat pulse gain.
var _model_materials: Dictionary[String, ShaderMaterial] = {}


func _init(cache: MaterialCache) -> void:
	_cache = cache


static func handles(visual: HazardDefinition.Visual) -> bool:
	return visual in [HazardDefinition.Visual.LASER, HazardDefinition.Visual.PENDULUM, HazardDefinition.Visual.MINE,
			HazardDefinition.Visual.CRUSHER, HazardDefinition.Visual.LASER_WALL, HazardDefinition.Visual.RING_GATE,
			HazardDefinition.Visual.MACE_SWEEP, HazardDefinition.Visual.ROLLING_BALL]


func build(root: Node3D, hazard: HazardDefinition) -> void:
	match hazard.visual:
		HazardDefinition.Visual.LASER:
			root.add_child(_model(LASER_FENCE, hazard.color, LASER_PULSE_GAIN))
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
			var grid: Node3D = _model(LASER_WALL, hazard.color, LASER_PULSE_GAIN)
			grid.position = Vector3(0.0, 0.0, hazard.lateral_center)
			root.add_child(grid)
			root.add_child(_field(hazard, Vector2(hazard.visual_width, hazard.visual_height),
					Vector3(0.0, hazard.visual_height * 0.5, hazard.lateral_center), false))
		HazardDefinition.Visual.MACE_SWEEP:
			root.add_child(_model(MACE_GANTRY, hazard.color))
			var mace: Node3D = _model(SPIKED_MACE, hazard.color)
			mace.name = ObstacleFactory.MOVING_PART
			mace.position = Vector3(0.0, MACE_PIVOT, 0.0)
			root.add_child(mace)
		HazardDefinition.Visual.ROLLING_BALL:
			var ball: Node3D = _model(SPIKED_MACE, hazard.color)
			ball.name = ObstacleFactory.MOVING_PART
			ball.position = Vector3(0.0, BALL_RADIUS, hazard.lateral_center)
			ball.scale = Vector3.ONE * BALL_SCALE
			root.add_child(ball)
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
		HazardDefinition.Visual.MACE_SWEEP:
			# Sweeps down the road toward the player and fills it exactly as the player rolls under the track.
			part.rotation.z = deg_to_rad(MACE_SWING_DEG) * sin(PI * (beat - hazard_beat))
		HazardDefinition.Visual.MINE:
			part.position.y = hazard.visual_height + 0.1 * sin(beat * PI)
			part.rotation.y = beat * 0.25 * TAU
		HazardDefinition.Visual.CRUSHER:
			# Slams down to its lowest point on every beat, then winds back up.
			var phase: float = beat - floorf(beat)
			part.position.y = hazard.bottom + CRUSHER_MARGIN + 0.55 * (1.0 - exp(-phase * 5.0))
		HazardDefinition.Visual.RING_GATE:
			part.rotation.x = beat * 0.125 * TAU
		HazardDefinition.Visual.PISTON:
			# Fully up on every beat (so whenever the player reaches it), sunk halfway between beats.
			part.scale.y = lerpf(PISTON_LOW, 1.0, 0.5 + 0.5 * cos(TAU * (beat - hazard_beat)))
		HazardDefinition.Visual.ROLLING_BALL:
			# Rolls down the road at the player and sits over its hitbox exactly at the hazard beat.
			part.position.x = (hazard_beat - beat) * BALL_SPEED
			part.rotation.z = part.position.x / BALL_RADIUS


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


func _model(scene: PackedScene, color: Color, pulse_gain: float = 0.8) -> Node3D:
	var key: String = "%s_%.1f" % [color.to_html(), pulse_gain]
	if not _model_materials.has(key):
		_model_materials[key] = NeonModel.create_material(color, color, GLOW_ENERGY, pulse_gain)
	return NeonModel.instantiate_shared(scene, _model_materials[key])
