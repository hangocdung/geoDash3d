# Visual player cube: follows the simulation pose on the track, rolls forward while airborne (a quarter
# turn per beat, snapped to the nearest face on landing), rolls sideways on dodges, swings around the
# edge on flips, squashes on landing, shows a ring while a shield is held and leaves a pixel trail. A beat
# ring on the ground under the player sends out a wave on every beat and takes the color of the next tap's
# action as it approaches (stays on the ground while jumping, hidden over gaps and while flipping; on the
# underside during underside runs, where the cube hangs upside down). Read-only.
# Related: src/gameplay/simulation/run_simulation.gd, src/presentation/shaders/neon_box.gdshader
class_name PlayerView
extends Node3D

const BOX_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const GLYPH_SHADER: Shader = preload("res://src/presentation/shaders/glyph.gdshader")
const CUBE_SIZE: float = 1.0
const LAND_SQUASH_DECAY: float = 7.0
const PLAYER_COLOR: Color = Color(0.3, 0.95, 1.0)
const SHIELD_COLOR: Color = Color(0.6, 0.75, 1.0)
const SHIELD_RING_SIZE: float = 2.1
const ROLL_PER_BEAT: float = PI * 0.5
## How fast the leftover roll settles after a landing snaps the cube flat (per second).
const ROLL_SNAP_RATE: float = 18.0
const FOOT_RING_SIZE: float = 2.6
const FOOT_RING_GLYPH: int = 10
## The foot ring turns to the next cue's action color over this many beats before it.
const FOOT_RING_LEAD_BEATS: float = 2.0

var body: MeshInstance3D
var trail: GPUParticles3D
var _shield_ring: MeshInstance3D
var _foot_ring: MeshInstance3D
var _foot_material: ShaderMaterial
## First cue at or after the last posed beat (the foot ring's color target).
var _next_cue: int = 0
var _context: LevelContext
var _roll_base: float = 0.0
## Roll still to settle after landing (the cube eases onto its nearest face).
var _roll_residual: float = 0.0
var _land_squash: float = 0.0
var _flash: float = 0.0


func setup(context: LevelContext) -> void:
	_context = context
	body = MeshInstance3D.new()
	body.name = "Body"
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * CUBE_SIZE
	body.mesh = cube
	var material := ShaderMaterial.new()
	material.shader = BOX_SHADER
	material.set_shader_parameter("edge_color", PLAYER_COLOR)
	material.set_shader_parameter("edge_energy", 4.0)
	material.set_shader_parameter("edge_width", 0.07)
	material.set_shader_parameter("face_energy", 0.22)
	material.set_shader_parameter("draw_face", true)
	body.material_override = material
	add_child(body)
	trail = TrailParticles.create(PLAYER_COLOR, QualityTier.particle_scale(context.quality))
	trail.position = Vector3(-CUBE_SIZE * 0.45, CUBE_SIZE * 0.5, 0.0)
	add_child(trail)
	_shield_ring = _create_shield_ring()
	add_child(_shield_ring)
	_foot_ring = _create_foot_ring()
	# Top level: placed on the ground in world space while the cube jumps.
	_foot_ring.top_level = true
	add_child(_foot_ring)


func reset_view() -> void:
	_roll_base = 0.0
	_roll_residual = 0.0
	_land_squash = 0.0
	_flash = 0.0
	visible = true
	_shield_ring.visible = false
	_next_cue = 0
	trail.emitting = true
	trail.restart()


func update_pose(beat: float, simulation: RunSimulation, delta: float) -> void:
	var frame: Transform3D = _context.frame_at_beat(beat)
	var action: ActionDefinition = simulation.active_action()
	var progress: float = simulation.action_progress_at(beat)
	var offset: Vector2 = simulation.player_offset_at(beat)
	var air_beats: float = simulation.air_beats_at(beat)
	_roll_residual *= exp(-ROLL_SNAP_RATE * delta)
	var forward_roll: float = _roll_base - air_beats * ROLL_PER_BEAT if air_beats >= 0.0 else _roll_base + _roll_residual
	var underside: bool = simulation.is_underside()
	var side_roll: float = PI if underside else 0.0
	if action != null and progress >= 0.0:
		var hold: float = action.hold_amount(progress)
		match action.kind:
			ActionDefinition.Kind.DODGE:
				# Roll a quarter turn toward the target lane and back again.
				side_roll = signf(action.lateral_distance) * hold * PI * 0.5
			ActionDefinition.Kind.FLIP:
				# Around the track edge: upside-down under the track, then back (flip) or on around the other
				# edge (roll, a full turn).
				side_roll = action.flip_angle(progress)
	_land_squash = maxf(_land_squash - delta * LAND_SQUASH_DECAY, 0.0)
	var stretch := Vector3(1.0 + 0.18 * _land_squash, 1.0 - 0.22 * _land_squash, 1.0 + 0.18 * _land_squash)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	body.set_instance_shader_parameter("flash", _flash)
	global_transform = frame * Transform3D(Basis(), Vector3(0.0, offset.y, offset.x))
	var rotation_basis: Basis = Basis(Vector3.RIGHT, side_roll) * Basis(Vector3.BACK, forward_roll)
	# Rotate around the cube center; squash around the face on the ground so the cube stays planted.
	var half: float = CUBE_SIZE * 0.5
	var center: float = CUBE_SIZE - half * stretch.y if underside else half * stretch.y
	body.transform = Transform3D(rotation_basis.scaled(stretch), Vector3(0.0, center, 0.0))
	_update_foot_ring(beat, offset, underside)


func _update_foot_ring(beat: float, offset: Vector2, underside: bool) -> void:
	var chart: LevelChart = _context.chart
	var distance: float = chart.distance_at(beat)
	var ground: float = chart.terrain.height_at(distance)
	_foot_ring.visible = underside or (not Terrain.is_gap(ground) and offset.y > -0.5)
	if not _foot_ring.visible:
		return
	var ground_frame: Transform3D = _context.underside_frame_at(beat) if underside \
			else _context.frame_at_height(beat, ground)
	_foot_ring.global_transform = ground_frame * Transform3D(Basis(), Vector3(0.0, 0.05, offset.x))
	if _next_cue > 0 and chart.cues[_next_cue - 1].beat > beat:
		_next_cue = 0
	while _next_cue < chart.cues.size() and chart.cues[_next_cue].beat < beat:
		_next_cue += 1
	var color: Color = PLAYER_COLOR
	if _next_cue < chart.cues.size():
		var cue: ChartItems.ActionCue = chart.cues[_next_cue]
		var closeness: float = 1.0 - clampf((cue.beat - beat) / FOOT_RING_LEAD_BEATS, 0.0, 1.0)
		color = PLAYER_COLOR.lerp(cue.action.color, smoothstep(0.0, 1.0, closeness))
	_foot_material.set_shader_parameter("glyph_color", color)
	_foot_ring.set_instance_shader_parameter("flash", _flash)


## Snaps the roll to the nearest face; the remainder eases out over a few frames.
func on_landed(airtime_beats: float) -> void:
	var landed_roll: float = _roll_base - airtime_beats * ROLL_PER_BEAT
	_roll_base = roundf(landed_roll / ROLL_PER_BEAT) * ROLL_PER_BEAT
	_roll_residual = landed_roll - _roll_base
	_land_squash = 1.0


func on_action_finished(action: ActionDefinition) -> void:
	_land_squash = 0.7 if action.kind == ActionDefinition.Kind.FLIP else 0.4


func set_shield(active: bool) -> void:
	_shield_ring.visible = active


func on_cue_hit(grade: Judgement.Grade) -> void:
	_flash = 1.0 if grade == Judgement.Grade.PERFECT else 0.5


func on_died() -> void:
	visible = false
	_foot_ring.visible = false
	trail.emitting = false


## Camera-facing ring around the cube (glyph ring), pulsing with the beat like every neon glyph.
func _create_shield_ring() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(SHIELD_RING_SIZE, SHIELD_RING_SIZE)
	ring.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = GLYPH_SHADER
	material.set_shader_parameter("glyph", 0)
	material.set_shader_parameter("billboard", true)
	material.set_shader_parameter("glyph_color", SHIELD_COLOR)
	material.set_shader_parameter("energy", 1.6)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, CUBE_SIZE * 0.5, 0.0)
	ring.visible = false
	return ring


## Flat beat ring on the ground (glyph 10); its color follows the next cue.
func _create_foot_ring() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = "FootRing"
	var plane := PlaneMesh.new()
	plane.size = Vector2(FOOT_RING_SIZE, FOOT_RING_SIZE)
	ring.mesh = plane
	_foot_material = ShaderMaterial.new()
	_foot_material.shader = GLYPH_SHADER
	_foot_material.set_shader_parameter("glyph", FOOT_RING_GLYPH)
	_foot_material.set_shader_parameter("glyph_color", PLAYER_COLOR)
	_foot_material.set_shader_parameter("energy", 1.8)
	ring.material_override = _foot_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


## World-space center of the cube (for camera and effects).
func center_position() -> Vector3:
	return body.global_transform.origin
