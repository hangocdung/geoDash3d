# Tunable gameplay numbers: timing windows, player hitbox, simulation step and the
# action/hazard libraries. `create_default()` builds the baseline set used by charts.
# Related: src/gameplay/defs/action_definition.gd, src/gameplay/defs/hazard_definition.gd
class_name GameplayConfig
extends Resource

## A tap within this many seconds of a cue performs that cue's action.
@export var cue_window_sec: float = 0.15
@export var perfect_window_sec: float = 0.045
@export var great_window_sec: float = 0.09
## Taps during an action are buffered if they land this close to the action's end.
@export var input_buffer_sec: float = 0.1
@export var player_half_length: float = 0.38
@export var player_bottom: float = 0.05
@export var player_top: float = 0.9
## Collision sampling step. Fixed in beats so results never depend on frame rate.
@export var simulation_step_beats: float = 1.0 / 96.0
@export var default_action: StringName = &"jump"
@export var actions: Array[ActionDefinition] = []
@export var hazards: Array[HazardDefinition] = []


static func create_default() -> GameplayConfig:
	var config := GameplayConfig.new()

	var jump := ActionDefinition.new()
	jump.id = &"jump"
	jump.duration_beats = 1.0
	jump.jump_height = 2.0
	jump.paired_hazard = &"spike"
	jump.hazard_beat_offset = 0.5
	jump.color = Color(1.0, 0.25, 0.85)

	var dash := ActionDefinition.new()
	dash.id = &"dash"
	dash.duration_beats = 0.75
	dash.lunge_distance = 1.6
	dash.immune_to = [&"barrier"]
	dash.paired_hazard = &"barrier"
	dash.hazard_beat_offset = 0.375
	dash.color = Color(1.0, 0.78, 0.2)

	var spike := HazardDefinition.new()
	spike.id = &"spike"
	spike.half_length = 0.32
	spike.top = 0.85
	spike.visual_length = 1.0
	spike.visual_height = 1.15
	spike.color = jump.color

	var barrier := HazardDefinition.new()
	barrier.id = &"barrier"
	barrier.half_length = 0.15
	barrier.top = 4.0
	barrier.visual_length = 0.3
	barrier.visual_height = 3.2
	barrier.color = dash.color

	config.actions = [jump, dash]
	config.hazards = [spike, barrier]
	return config


func find_action(action_id: StringName) -> ActionDefinition:
	for action: ActionDefinition in actions:
		if action.id == action_id:
			return action
	return null


func find_hazard(hazard_id: StringName) -> HazardDefinition:
	for hazard: HazardDefinition in hazards:
		if hazard.id == hazard_id:
			return hazard
	return null
