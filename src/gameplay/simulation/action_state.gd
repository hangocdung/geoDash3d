# The dodge or flip in progress (fixed duration; jumps live in VerticalMotion) and the side of the track the
# player runs on: an underside run starts when a flip_down ends and ends when its flip_up starts (GD3-112).
# Related: run_simulation.gd, src/gameplay/defs/action_definition.gd
class_name ActionState
extends RefCounted

var action: ActionDefinition = null
var start_beat: float = 0.0
## Running upside down under the track.
var underside: bool = false


func start(new_action: ActionDefinition, beat: float) -> void:
	action = new_action
	start_beat = beat
	if new_action.flip_part == ActionDefinition.FlipPart.UP:
		# The way back up starts from the underside; from here on the road's top is the ground again.
		underside = false


func is_active() -> bool:
	return action != null


func end_beat() -> float:
	return start_beat + action.duration_beats


## Ends the action once `beat` reaches its end and returns it (null when nothing ended).
func finish_if_due(beat: float) -> ActionDefinition:
	if action == null or beat < end_beat():
		return null
	var finished: ActionDefinition = action
	action = null
	if finished.flip_part == ActionDefinition.FlipPart.DOWN:
		underside = true
	return finished


## After a forgiven hit (shield, practice): back onto the side of the track the perfect run is on, so a missed
## flip_down or flip_up does not leave the player on the wrong side for the rest of the level.
func follow_run(chart: LevelChart, beat: float) -> void:
	if action == null:
		underside = chart.is_underside_at(beat)


func progress_at(beat: float) -> float:
	return clampf((beat - start_beat) / action.duration_beats, 0.0, 1.0)


## Offset from the track surface for a body `height` above its ground (see RunSimulation.player_offset_at).
func offset_at(beat: float, height: float, underside_depth: float) -> Vector2:
	if action != null:
		return Vector2(0.0, height) + action.offset_at(progress_at(beat))
	if underside:
		# Upside down under the track: jumps take the player further down, away from the underside.
		return Vector2(0.0, -underside_depth - height)
	return Vector2(0.0, height)
