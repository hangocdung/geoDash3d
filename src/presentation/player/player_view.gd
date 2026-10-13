# Visual player cube: follows the simulation pose on the track, rolls 90° per jump, lunges and
# stretches on dash, squashes on landing and leaves a pixel trail. Reads state, never writes it.
# Related: src/gameplay/simulation/run_simulation.gd, src/presentation/shaders/neon_box.gdshader
class_name PlayerView
extends Node3D

const BOX_SHADER: Shader = preload("res://src/presentation/shaders/neon_box.gdshader")
const CUBE_SIZE: float = 1.0
const LAND_SQUASH_DECAY: float = 7.0
const PLAYER_COLOR: Color = Color(0.3, 0.95, 1.0)

var body: MeshInstance3D
var trail: GPUParticles3D
var _context: LevelContext
var _roll_base: float = 0.0
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
	_land_squash = 0.0
	_flash = 0.0
	visible = true
	trail.emitting = true
	trail.restart()


func update_pose(beat: float, simulation: RunSimulation, delta: float) -> void:
	var frame: Transform3D = _context.frame_at_beat(beat)
	var action: ActionDefinition = simulation.active_action()
	var progress: float = simulation.action_progress_at(beat)
	var height: float = simulation.player_height_at(beat)
	var lunge: float = 0.0
	var roll: float = _roll_base
	var stretch := Vector3.ONE
	if action != null and progress >= 0.0:
		if action.jump_height > 0.0:
			roll -= progress * PI * 0.5
		if action.lunge_distance > 0.0:
			var arc: float = sin(progress * PI)
			lunge = action.lunge_distance * arc
			stretch = Vector3(1.0 + 0.45 * arc, 1.0 - 0.2 * arc, 1.0 - 0.2 * arc)
	_land_squash = maxf(_land_squash - delta * LAND_SQUASH_DECAY, 0.0)
	stretch *= Vector3(1.0 + 0.18 * _land_squash, 1.0 - 0.22 * _land_squash, 1.0 + 0.18 * _land_squash)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	body.set_instance_shader_parameter("flash", _flash)
	global_transform = frame * Transform3D(Basis(), Vector3(lunge, height, 0.0))
	# Squash around the bottom so the cube stays planted on the track.
	var half: float = CUBE_SIZE * 0.5
	body.transform = Transform3D(Basis(Vector3.BACK, roll).scaled(stretch),
			Vector3(0.0, half * stretch.y, 0.0))


func on_action_finished(action: ActionDefinition) -> void:
	if action.jump_height > 0.0:
		_roll_base -= PI * 0.5
		_land_squash = 1.0
	else:
		_land_squash = 0.5


func on_cue_hit(grade: Judgement.Grade) -> void:
	_flash = 1.0 if grade == Judgement.Grade.PERFECT else 0.5


func on_died() -> void:
	visible = false
	trail.emitting = false


## World-space center of the cube (for camera and effects).
func center_position() -> Vector3:
	return body.global_transform.origin
