# Data for one tap action. Motion is analytic in beats (scales with tempo) and never changes the
# run speed. A chart event of this action also spawns `paired_hazard` at cue + `hazard_beat_offset`.
# JUMP is a ballistic launch (see launch_velocity / gravity); it lasts until the player lands.
# Related: src/gameplay/defs/gameplay_config.gd, src/gameplay/simulation/run_simulation.gd
class_name ActionDefinition
extends Resource

enum Kind {
	## Ballistic launch; on flat ground it lands after `duration_beats`, peaking at `jump_height`.
	JUMP,
	## Slide to a side lane, hold, slide back (lateral_distance is signed: negative = left).
	DODGE,
	## Wrap around the track edge to run upside-down under the track, then wrap back.
	FLIP,
}
## FLIP: the whole trip under the track and back (flip, roll), or only half of an underside run (GD3-112):
## DOWN ends upside-down under the track, UP comes back up the other edge (together they make one full turn).
enum FlipPart { ROUND_TRIP, DOWN, UP }

@export var id: StringName = &""
@export var kind: Kind = Kind.JUMP
@export var duration_beats: float = 1.0
## JUMP: peak height of the parabola (on flat ground).
@export var jump_height: float = 0.0
## JUMP: may be performed in mid-air (jump orbs). Other jumps need the player on the ground.
@export var air_allowed: bool = false
## JUMP: > 0 launches straight down at this speed (units/beat) instead of up (dive orb); same gravity.
@export var dive_speed: float = 0.0
## DODGE: signed lateral target. FLIP: how far sideways the player swings around the track edge.
@export var lateral_distance: float = 0.0
## DODGE / FLIP: fraction of the action spent moving out (and the same fraction moving back).
@export var transition_fraction: float = 0.2
## FLIP: depth of the player's lower edge when hanging under the track (track thickness + cube size).
@export var flip_depth: float = 0.0
## FLIP: keep going around instead of wrapping back: over one edge, under the track, up the other edge (roll).
@export var full_turn: bool = false
@export var flip_part: FlipPart = FlipPart.ROUND_TRIP
## Hazard ids that cannot hurt the player while this action is active.
@export var immune_to: Array[StringName] = []
@export var paired_hazard: StringName = &""
@export var hazard_beat_offset: float = 0.5
## UI/VFX color associated with this action (cue markers, paired hazard tint).
@export var color: Color = Color.WHITE
## Sound played when the action starts (see tools/audio/sfx_spec.py).
@export var start_sound: StringName = &""


## JUMP: initial upward speed in units per beat (lands after duration_beats on flat ground).
func launch_velocity() -> float:
	if dive_speed > 0.0:
		return -dive_speed
	return 4.0 * jump_height / duration_beats


## JUMP: downward acceleration in units per beat².
func gravity() -> float:
	return 8.0 * jump_height / (duration_beats * duration_beats)


## Player offset from its resting spot: x = lateral (+ = right), y = height of the player's lower edge.
## JUMP is the flat-ground parabola; RunSimulation integrates real jumps against the terrain.
func offset_at(progress: float) -> Vector2:
	if kind == Kind.FLIP:
		# Angle-based even at the ends: DOWN finishes (and UP starts) under the track.
		var angle: float = flip_angle(clampf(progress, 0.0, 1.0))
		return Vector2(sin(angle) * lateral_distance, (cos(angle) - 1.0) * flip_depth * 0.5)
	if progress <= 0.0 or progress >= 1.0:
		return Vector2.ZERO
	match kind:
		Kind.JUMP:
			return Vector2(0.0, 4.0 * jump_height * progress * (1.0 - progress))
		Kind.DODGE:
			return Vector2(lateral_distance * hold_amount(progress), 0.0)
	return Vector2.ZERO


## FLIP: angle around the track's length axis (0 = on the road, PI = under it). A flip wraps back to 0; a
## full turn goes on to TAU, coming up the other edge.
func flip_angle(progress: float) -> float:
	match flip_part:
		FlipPart.DOWN:
			return PI * smoothstep(0.0, 1.0, progress)
		FlipPart.UP:
			return PI + PI * smoothstep(0.0, 1.0, progress)
	if full_turn and progress >= 0.5:
		return PI * (2.0 - hold_amount(progress)) if progress < 1.0 else 0.0
	return PI * hold_amount(progress)


## 0 → 1 while transitioning out, 1 while holding, 1 → 0 while transitioning back.
func hold_amount(progress: float) -> float:
	if progress <= 0.0 or progress >= 1.0:
		return 0.0
	var fraction: float = clampf(transition_fraction, 0.01, 0.5)
	if progress < fraction:
		return smoothstep(0.0, fraction, progress)
	if progress > 1.0 - fraction:
		return 1.0 - smoothstep(1.0 - fraction, 1.0, progress)
	return 1.0


func is_immune_to(hazard_id: StringName) -> bool:
	return immune_to.has(hazard_id)
