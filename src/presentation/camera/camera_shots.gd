# Named camera shots expressed in the player's track frame (X forward, Y up, Z = camera side).
# Every shot keeps at least ~1 s of track ahead visible. Add new shots here, use them in charts.
# Portrait screens (GD3-210) replace each chart shot with a behind/above variant: the track runs up the screen,
# so far more of it is visible ahead than from the side in a narrow 9:16 view.
# Related: src/presentation/camera/camera_director.gd
class_name CameraShots
extends RefCounted

const DEFAULT_SHOT: StringName = &"side"
## Used automatically while the player runs under the track (flip).
const UNDERSIDE_SHOT: StringName = &"underside"


class Shot:
	var position: Vector3
	var look_at: Vector3
	var fov: float
	## Extra roll (degrees) for dramatic shots.
	var roll_deg: float

	func _init(shot_position: Vector3, shot_look_at: Vector3, shot_fov: float, shot_roll: float = 0.0) -> void:
		position = shot_position
		look_at = shot_look_at
		fov = shot_fov
		roll_deg = shot_roll

	func blended(other: Shot, weight: float) -> Shot:
		return Shot.new(position.lerp(other.position, weight), look_at.lerp(other.look_at, weight),
				lerpf(fov, other.fov, weight), lerpf(roll_deg, other.roll_deg, weight))


static func get_shot(shot_name: StringName, portrait: bool = false) -> Shot:
	if portrait:
		return _portrait_shot(shot_name)
	match shot_name:
		&"side":
			return Shot.new(Vector3(2.0, 3.2, 14.0), Vector3(6.0, 1.2, 0.0), 58.0)
		&"side_low":
			return Shot.new(Vector3(1.5, 1.1, 10.0), Vector3(5.0, 1.8, 0.0), 62.0)
		&"side_high":
			return Shot.new(Vector3(-1.0, 10.0, 15.0), Vector3(7.0, 0.0, 0.0), 55.0)
		&"side_far":
			return Shot.new(Vector3(4.0, 5.0, 24.0), Vector3(8.0, 1.0, 0.0), 50.0)
		&"chase":
			return Shot.new(Vector3(-9.0, 4.2, 2.2), Vector3(9.0, 0.8, 0.0), 64.0)
		&"chase_low":
			return Shot.new(Vector3(-6.5, 1.4, 3.0), Vector3(10.0, 1.6, -0.5), 70.0, -6.0)
		&"high":
			return Shot.new(Vector3(-3.0, 17.0, 7.0), Vector3(8.0, 0.0, 0.0), 55.0)
		&"diagonal":
			return Shot.new(Vector3(-5.0, 5.5, 10.0), Vector3(8.0, 0.8, 0.0), 60.0, 4.0)
		&"front":
			return Shot.new(Vector3(13.0, 2.6, 6.0), Vector3(0.0, 1.0, 0.0), 58.0)
		&"underside":
			return Shot.new(Vector3(1.5, -0.6, 12.5), Vector3(5.5, -1.4, 0.0), 60.0)
	push_warning("CameraShots: unknown shot '%s', using '%s'" % [shot_name, DEFAULT_SHOT])
	return get_shot(DEFAULT_SHOT)


## Behind/above shots for 9:16: chase for the side family, low and high variants, a slanted one for
## diagonal, a wider front for the intro, and a low chase under the track for underside runs.
static func _portrait_shot(shot_name: StringName) -> Shot:
	match shot_name:
		&"side", &"side_far", &"chase":
			return Shot.new(Vector3(-9.5, 7.0, 0.6), Vector3(12.0, -0.5, 0.0), 70.0)
		&"side_low", &"chase_low":
			return Shot.new(Vector3(-8.0, 3.6, 0.6), Vector3(12.0, 0.4, 0.0), 74.0, -4.0)
		&"side_high", &"high":
			return Shot.new(Vector3(-6.0, 12.0, 0.6), Vector3(14.0, 0.0, 0.0), 68.0)
		&"diagonal":
			return Shot.new(Vector3(-7.5, 6.5, 2.5), Vector3(12.0, 0.5, -1.0), 70.0, 3.0)
		&"front":
			return Shot.new(Vector3(14.0, 3.0, 1.5), Vector3(0.0, 1.0, 0.0), 74.0)
		&"underside":
			return Shot.new(Vector3(-7.0, -3.2, 0.6), Vector3(12.0, -1.6, 0.0), 74.0)
	push_warning("CameraShots: unknown shot '%s', using '%s'" % [shot_name, DEFAULT_SHOT])
	return _portrait_shot(DEFAULT_SHOT)


static func names() -> PackedStringArray:
	return PackedStringArray(["side", "side_low", "side_high", "side_far", "chase", "chase_low", "high",
			"diagonal", "front", "underside"])
