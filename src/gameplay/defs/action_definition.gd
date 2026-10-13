# Data for one tap action (jump, dash, ...). Motion is analytic in beats, so it scales with tempo.
# A chart event of this action type also spawns `paired_hazard` at cue beat + `hazard_beat_offset`.
# Related: src/gameplay/defs/gameplay_config.gd, src/gameplay/simulation/run_simulation.gd
class_name ActionDefinition
extends Resource

@export var id: StringName = &""
@export var duration_beats: float = 1.0
## Peak height of the vertical parabola (0 = stays on the ground).
@export var jump_height: float = 0.0
## Presentation-only forward lunge distance at the middle of the action.
@export var lunge_distance: float = 0.0
## Hazard ids that cannot kill the player while this action is active.
@export var immune_to: Array[StringName] = []
@export var paired_hazard: StringName = &""
@export var hazard_beat_offset: float = 0.5
## UI/VFX color associated with this action (cue pads, hazard tint).
@export var color: Color = Color.WHITE


func height_at(progress: float) -> float:
	if progress <= 0.0 or progress >= 1.0:
		return 0.0
	return 4.0 * jump_height * progress * (1.0 - progress)


func is_immune_to(hazard_id: StringName) -> bool:
	return immune_to.has(hazard_id)
