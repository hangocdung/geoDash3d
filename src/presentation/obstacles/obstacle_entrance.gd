# Beat-synced entrance animations as pure functions of "beats since landing" (negative = before).
# RISE grows out of the floor, DROP falls and squashes, UNFOLD opens sideways. Landing hits a whole beat.
# Related: obstacle_view.gd, src/gameplay/defs/hazard_definition.gd
class_name ObstacleEntrance
extends RefCounted

const RISE_BEATS: float = 0.25
const DROP_BEATS: float = 0.5
const UNFOLD_BEATS: float = 0.375
const SETTLE_BEATS: float = 0.3
const DROP_HEIGHT: float = 14.0


## Beats before landing at which the obstacle becomes visible.
static func lead_in(entrance: HazardDefinition.Entrance) -> float:
	match entrance:
		HazardDefinition.Entrance.DROP:
			return DROP_BEATS
		HazardDefinition.Entrance.UNFOLD:
			return UNFOLD_BEATS
	return RISE_BEATS


## Local offset/scale relative to the resting transform. `t` = beats since landing.
static func pose(entrance: HazardDefinition.Entrance, t: float, height: float) -> Transform3D:
	var duration: float = lead_in(entrance)
	var before: bool = t < 0.0
	var u: float = clampf((t + duration) / duration, 0.0, 1.0)
	var settle: float = clampf(t / SETTLE_BEATS, 0.0, 1.0)
	match entrance:
		HazardDefinition.Entrance.RISE:
			if before:
				var eased: float = 1.0 - pow(1.0 - u, 3.0)
				return Transform3D(Basis().scaled(Vector3(1.0, lerpf(0.5, 1.0, u), 1.0)),
						Vector3(0, -height * (1.0 - eased), 0))
			var bounce: float = sin(settle * PI) * 0.12 * height * (1.0 - settle)
			return Transform3D(Basis(), Vector3(0, bounce, 0))
		HazardDefinition.Entrance.DROP:
			if before:
				return Transform3D(Basis(), Vector3(0, DROP_HEIGHT * (1.0 - u * u), 0))
			var squash: float = 0.22 * (1.0 - settle)
			return Transform3D(Basis().scaled(Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5)), Vector3.ZERO)
		HazardDefinition.Entrance.UNFOLD:
			if before:
				return Transform3D(Basis().scaled(Vector3(1.0, 1.0, maxf(_ease_out_back(u), 0.02))), Vector3.ZERO)
			var wobble: float = 1.0 + sin(settle * PI) * 0.06 * (1.0 - settle)
			return Transform3D(Basis().scaled(Vector3(1.0, 1.0, wobble)), Vector3.ZERO)
	return Transform3D()


static func _ease_out_back(u: float) -> float:
	const OVERSHOOT: float = 1.7
	var v: float = u - 1.0
	return 1.0 + (OVERSHOOT + 1.0) * v * v * v + OVERSHOOT * v * v
