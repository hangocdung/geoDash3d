# Visual player cube: follows the simulation pose on the track, rolls forward while airborne (a quarter
# turn per beat, snapped to the nearest face on landing), rolls sideways on dodges, swings around the
# edge on flips, squashes on landing and leaves a pixel trail. Read-only.
# Related: src/gameplay/simulation/run_simulation.gd, src/presentation/shaders/neon_box.gdshader
class_name PlayerView
extends Node3D

const BOX_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const CUBE_SIZE: float = 1.0
const LAND_SQUASH_DECAY: float = 7.0
const PLAYER_COLOR: Color = Color(0.3, 0.95, 1.0)
const ROLL_PER_BEAT: float = PI * 0.5
## How fast the leftover roll settles after a landing snaps the cube flat (per second).
const ROLL_SNAP_RATE: float = 18.0

var body: MeshInstance3D
var trail: GPUParticles3D
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
	material.set_shader_parameter("edge_energy", 6.0)
	material.set_shader_parameter("edge_width", 0.07)
	material.set_shader_parameter("face_energy", 0.35)
	material.set_shader_parameter("draw_face", true)
	body.material_override = material
	add_child(body)
	trail = TrailParticles.create(PLAYER_COLOR, QualityTier.particle_scale(context.quality))
	trail.position = Vector3(-CUBE_SIZE * 0.45, CUBE_SIZE * 0.5, 0.0)
	add_child(trail)


func reset_view() -> void:
	_roll_base = 0.0
	_roll_residual = 0.0
	_land_squash = 0.0
	_flash = 0.0
	visible = true
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
	var side_roll: float = 0.0
	if action != null and progress >= 0.0:
		var hold: float = action.hold_amount(progress)
		match action.kind:
			ActionDefinition.Kind.DODGE:
				# Roll a quarter turn toward the target lane and back again.
				side_roll = signf(action.lateral_distance) * hold * PI * 0.5
			ActionDefinition.Kind.FLIP:
				# Half turn around the track edge: the cube ends up upside-down under the track.
				side_roll = hold * PI
	_land_squash = maxf(_land_squash - delta * LAND_SQUASH_DECAY, 0.0)
	var stretch := Vector3(1.0 + 0.18 * _land_squash, 1.0 - 0.22 * _land_squash, 1.0 + 0.18 * _land_squash)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	body.set_instance_shader_parameter("flash", _flash)
	global_transform = frame * Transform3D(Basis(), Vector3(0.0, offset.y, offset.x))
	var rotation_basis: Basis = Basis(Vector3.RIGHT, side_roll) * Basis(Vector3.BACK, forward_roll)
	# Rotate around the cube center; squash around the bottom so the cube stays planted.
	var half: float = CUBE_SIZE * 0.5
	body.transform = Transform3D(rotation_basis.scaled(stretch), Vector3(0.0, half * stretch.y, 0.0))


## Snaps the roll to the nearest face; the remainder eases out over a few frames.
func on_landed(airtime_beats: float) -> void:
	var landed_roll: float = _roll_base - airtime_beats * ROLL_PER_BEAT
	_roll_base = roundf(landed_roll / ROLL_PER_BEAT) * ROLL_PER_BEAT
	_roll_residual = landed_roll - _roll_base
	_land_squash = 1.0


func on_action_finished(action: ActionDefinition) -> void:
	_land_squash = 0.7 if action.kind == ActionDefinition.Kind.FLIP else 0.4


func on_cue_hit(grade: Judgement.Grade) -> void:
	_flash = 1.0 if grade == Judgement.Grade.PERFECT else 0.5


func on_died() -> void:
	visible = false
	trail.emitting = false


## World-space center of the cube (for camera and effects).
func center_position() -> Vector3:
	return body.global_transform.origin
