# Drives the Camera3D from chart camera cues: the shot is a pure function of the beat (blended
# between cues), placed in the smoothed track frame raised to the (smoothed) terrain height. Adds shake
# and FOV kicks from events.
# Related: src/presentation/camera/camera_shots.gd, src/presentation/level/level_runner.gd
class_name CameraDirector
extends Node3D

const SHAKE_DECAY_PER_SEC: float = 2.8
const FOV_KICK_DECAY_PER_SEC: float = 3.0
const MAX_SHAKE_OFFSET: float = 0.45
## Fraction of the player's height above the ground that the camera follows.
const HEIGHT_FOLLOW: float = 0.35
## The camera rides on the terrain averaged over this radius, centred a little ahead of the player.
const GROUND_RADIUS: float = 9.0
const GROUND_LOOK_AHEAD: float = 4.0
const FRAME_SMOOTHING: float = 6.0

var camera: Camera3D
var _context: LevelContext
var _cues: Array[ChartItems.CameraCue] = []
var _trauma: float = 0.0
var _fov_kick: float = 0.0
var _noise := FastNoiseLite.new()
var _noise_time: float = 0.0
var _smoothed_frame: Transform3D
var _has_frame: bool = false


func setup(context: LevelContext) -> void:
	_context = context
	_cues = context.chart.camera_cues
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.1
	camera.far = 900.0
	add_child(camera)
	camera.make_current()
	_noise.frequency = 2.5


func reset_view() -> void:
	_trauma = 0.0
	_fov_kick = 0.0
	_has_frame = false


func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func add_fov_kick(degrees: float) -> void:
	_fov_kick = maxf(_fov_kick, degrees)


## `underside_amount` (0..1) blends toward a low side shot so flips under the track stay visible.
func update_camera(beat: float, player_height: float, underside_amount: float, delta: float) -> void:
	var shot: CameraShots.Shot = shot_at(beat)
	if underside_amount > 0.0:
		shot = shot.blended(CameraShots.get_shot(CameraShots.UNDERSIDE_SHOT), underside_amount)
	var target_frame: Transform3D = _context.frame_at_beat(beat)
	if not _has_frame:
		_smoothed_frame = target_frame
		_has_frame = true
	else:
		# Smooth only the rotation so turns feel cinematic; position stays locked to the player.
		var weight: float = 1.0 - exp(-FRAME_SMOOTHING * delta)
		var rotation_quat: Quaternion = _smoothed_frame.basis.get_rotation_quaternion().slerp(
				target_frame.basis.get_rotation_quaternion(), weight)
		_smoothed_frame = Transform3D(Basis(rotation_quat), target_frame.origin)
	var ground: float = _context.chart.terrain.smoothed_height_at(
			_context.chart.distance_at(beat) + GROUND_LOOK_AHEAD, GROUND_RADIUS)
	var lift: float = ground + (player_height - ground) * HEIGHT_FOLLOW
	var frame := Transform3D(_smoothed_frame.basis, target_frame.origin + _smoothed_frame.basis.y * lift)
	var eye: Vector3 = frame * shot.position
	var target: Vector3 = frame * shot.look_at
	_trauma = maxf(_trauma - delta * SHAKE_DECAY_PER_SEC, 0.0)
	_fov_kick = maxf(_fov_kick - delta * FOV_KICK_DECAY_PER_SEC * maxf(_fov_kick, 1.0), 0.0)
	_noise_time += delta
	var shake: float = _trauma * _trauma * MAX_SHAKE_OFFSET
	var jitter := Vector3(_noise.get_noise_2d(_noise_time * 60.0, 0.0), _noise.get_noise_2d(0.0, _noise_time * 60.0),
			_noise.get_noise_2d(_noise_time * 60.0, 50.0)) * shake
	var up: Vector3 = frame.basis.y.rotated((target - eye).normalized(), deg_to_rad(shot.roll_deg))
	camera.global_transform = Transform3D(Basis.looking_at(target - eye, up), eye + jitter)
	camera.fov = shot.fov + _fov_kick


## Blended shot at `beat` (deterministic: depends only on the chart and the beat).
func shot_at(beat: float) -> CameraShots.Shot:
	var current_index: int = -1
	for index: int in _cues.size():
		if _cues[index].beat > beat:
			break
		current_index = index
	if current_index < 0:
		return CameraShots.get_shot(_cues[0].shot if not _cues.is_empty() else CameraShots.DEFAULT_SHOT)
	var cue: ChartItems.CameraCue = _cues[current_index]
	var target: CameraShots.Shot = CameraShots.get_shot(cue.shot)
	if cue.blend_beats <= 0.0 or current_index == 0:
		return target
	var weight: float = clampf((beat - cue.beat) / cue.blend_beats, 0.0, 1.0)
	if weight >= 1.0:
		return target
	var previous: CameraShots.Shot = _settled_shot(current_index - 1, cue.beat)
	return previous.blended(target, smoothstep(0.0, 1.0, weight))


## Shot reached by cue `index` at `beat` (handles a cue that started before its blend finished).
func _settled_shot(index: int, beat: float) -> CameraShots.Shot:
	var cue: ChartItems.CameraCue = _cues[index]
	var target: CameraShots.Shot = CameraShots.get_shot(cue.shot)
	if index == 0 or cue.blend_beats <= 0.0 or beat >= cue.beat + cue.blend_beats:
		return target
	var weight: float = clampf((beat - cue.beat) / cue.blend_beats, 0.0, 1.0)
	return _settled_shot(index - 1, cue.beat).blended(target, smoothstep(0.0, 1.0, weight))
