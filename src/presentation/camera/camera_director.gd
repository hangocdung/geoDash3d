# Drives the Camera3D from chart camera cues: the shot is a pure function of the beat (blended
# between cues), placed in the smoothed track frame raised to the (smoothed) terrain height. Adds shake
# and FOV kicks from events. Flips swing it under the track; rolls and underside runs turn it around the
# track with the player (except on LOW, where a turning camera costs FPS: see QualityTier.uses_spectacle_track;
# LOW watches underside runs from the low underside shot instead).
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
## Portrait: the camera turns just enough to keep the cube inside these shares of the half field of view
## (sideways; up and down, measured from the centre). Lane changes, rolls and turns would push it off a narrow screen.
const PORTRAIT_SAFE_SIDE: float = 0.4
const PORTRAIT_SAFE_UP: float = 0.45
const PORTRAIT_SAFE_DOWN: float = 0.55

var camera: Camera3D
var _context: LevelContext
var _cues: Array[ChartItems.CameraCue] = []
var _trauma: float = 0.0
var _fov_kick: float = 0.0
var _noise := FastNoiseLite.new()
var _noise_time: float = 0.0
var _smoothed_frame: Transform3D
var _has_frame: bool = false
## 9:16 view (DisplayOrientation): chart shots are swapped for their portrait variants.
var _portrait: bool = false


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


## `player`: read only in portrait, to keep the cube inside the frame.
func update_camera(beat: float, simulation: RunSimulation, delta: float, player: PlayerView) -> void:
	var player_height: float = simulation.player_height_at(beat)
	_portrait = DisplayOrientation.is_portrait(get_viewport())
	var flip_pose: Vector2 = _flip_pose(simulation, beat)
	var underside_amount: float = flip_pose.x
	var roll: float = flip_pose.y
	var shot: CameraShots.Shot = shot_at(beat)
	if underside_amount > 0.0:
		shot = shot.blended(CameraShots.get_shot(CameraShots.UNDERSIDE_SHOT, _portrait), underside_amount)
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
	if roll != 0.0:
		# Turn around the track's centre line with the player (applied after smoothing: it is already smooth,
		# and smoothing a fast full turn could take the short way round).
		var half_thickness: float = _context.config.track_thickness * 0.5
		var axis_point: Vector3 = target_frame.origin - _smoothed_frame.basis.y * half_thickness
		var rolled: Basis = _smoothed_frame.basis * Basis(Vector3.RIGHT, roll)
		var rise: float = ground
		if simulation.is_underside():
			# Upside down under the road: follow jumps away from its underside.
			rise += (-player_height - _context.config.underside_depth()) * HEIGHT_FOLLOW
		frame = Transform3D(rolled, axis_point + rolled.y * (half_thickness + rise))
	var eye: Vector3 = frame * shot.position
	var target: Vector3 = frame * shot.look_at
	_trauma = maxf(_trauma - delta * SHAKE_DECAY_PER_SEC, 0.0)
	_fov_kick = maxf(_fov_kick - delta * FOV_KICK_DECAY_PER_SEC * maxf(_fov_kick, 1.0), 0.0)
	_noise_time += delta
	var shake: float = _trauma * _trauma * MAX_SHAKE_OFFSET
	var jitter := Vector3(_noise.get_noise_2d(_noise_time * 60.0, 0.0), _noise.get_noise_2d(0.0, _noise_time * 60.0),
			_noise.get_noise_2d(_noise_time * 60.0, 50.0)) * shake
	var up: Vector3 = frame.basis.y.rotated((target - eye).normalized(), deg_to_rad(shot.roll_deg))
	var view := Transform3D(Basis.looking_at(target - eye, up), eye)
	if _portrait:
		view = _keep_in_frame(view, shot.fov, player.center_position())
	camera.global_transform = Transform3D(view.basis, eye + jitter)
	camera.fov = shot.fov + _fov_kick


## Turns `view` (yaw, then pitch) by the least angle that brings `point` inside the portrait safe area.
func _keep_in_frame(view: Transform3D, fov_deg: float, point: Vector3) -> Transform3D:
	var local: Vector3 = view.affine_inverse() * point
	if local.z > -0.5:
		return view
	var size: Vector2 = get_viewport().get_visible_rect().size
	var half_up: float = deg_to_rad(fov_deg) * 0.5
	var half_side: float = atan(tan(half_up) * size.x / maxf(size.y, 1.0))
	var yaw: float = atan2(local.x, -local.z)
	var pitch: float = atan2(local.y, -local.z)
	var yaw_excess: float = yaw - clampf(yaw, -half_side * PORTRAIT_SAFE_SIDE, half_side * PORTRAIT_SAFE_SIDE)
	var pitch_excess: float = pitch - clampf(pitch, -half_up * PORTRAIT_SAFE_DOWN, half_up * PORTRAIT_SAFE_UP)
	if yaw_excess == 0.0 and pitch_excess == 0.0:
		return view
	var turned: Basis = view.basis * Basis(Vector3.UP, -yaw_excess) * Basis(Vector3.RIGHT, pitch_excess)
	return Transform3D(turned, view.origin)


## x = 0..1 blend toward the low underside shot (flips, and rolls and underside runs on LOW), y = camera roll
## around the track (rolls and underside runs on tiers with spectacle track shapes), eased so the swing is gentle.
func _flip_pose(simulation: RunSimulation, beat: float) -> Vector2:
	var turns: bool = QualityTier.uses_spectacle_track(_context.quality)
	var action: ActionDefinition = simulation.active_action()
	if action == null or action.kind != ActionDefinition.Kind.FLIP:
		if not simulation.is_underside():
			return Vector2.ZERO
		return Vector2(0.0, PI) if turns else Vector2(1.0, 0.0)
	var progress: float = simulation.action_progress_at(beat)
	if turns and (action.full_turn or action.flip_part != ActionDefinition.FlipPart.ROUND_TRIP):
		return Vector2(0.0, action.flip_angle(progress))
	match action.flip_part:
		ActionDefinition.FlipPart.DOWN:
			return Vector2(smoothstep(0.0, 0.6, progress), 0.0)
		ActionDefinition.FlipPart.UP:
			return Vector2(1.0 - smoothstep(0.4, 1.0, progress), 0.0)
	return Vector2(smoothstep(0.0, 0.3, progress) * (1.0 - smoothstep(0.75, 1.0, progress)), 0.0)


## Blended shot at `beat` (deterministic: depends only on the chart and the beat).
func shot_at(beat: float) -> CameraShots.Shot:
	var current_index: int = -1
	for index: int in _cues.size():
		if _cues[index].beat > beat:
			break
		current_index = index
	if current_index < 0:
		return CameraShots.get_shot(_cues[0].shot if not _cues.is_empty() else CameraShots.DEFAULT_SHOT, _portrait)
	var cue: ChartItems.CameraCue = _cues[current_index]
	var target: CameraShots.Shot = CameraShots.get_shot(cue.shot, _portrait)
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
	var target: CameraShots.Shot = CameraShots.get_shot(cue.shot, _portrait)
	if index == 0 or cue.blend_beats <= 0.0 or beat >= cue.beat + cue.blend_beats:
		return target
	var weight: float = clampf((beat - cue.beat) / cue.blend_beats, 0.0, 1.0)
	return _settled_shot(index - 1, cue.beat).blended(target, smoothstep(0.0, 1.0, weight))
