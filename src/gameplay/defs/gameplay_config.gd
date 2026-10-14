# Tunable gameplay numbers: timing windows, track/player dimensions, simulation step, terrain rules and
# the action/hazard libraries. `create_default()` builds the set used by charts (gameplay_v2/v3.md).
# Related: src/gameplay/defs/action_definition.gd, src/gameplay/defs/hazard_definition.gd
class_name GameplayConfig
extends Resource

## A tap within this many seconds of a cue performs that cue's action.
@export var cue_window_sec: float = 0.15
@export var perfect_window_sec: float = 0.045
@export var great_window_sec: float = 0.09
## Taps during an action are buffered if they land this close to the action's end.
@export var input_buffer_sec: float = 0.1
@export var track_width: float = 3.0
@export var track_thickness: float = 1.1
@export var lane_width: float = 1.0
@export var player_half_length: float = 0.38
@export var player_half_width: float = 0.38
@export var player_bottom: float = 0.05
@export var player_top: float = 0.9
## Collision sampling step. Fixed in beats so results never depend on frame rate.
@export var simulation_step_beats: float = 1.0 / 96.0
@export var default_action: StringName = &"jump"
## Feet up to this far below a ledge top still land on it instead of hitting its side.
@export var step_snap: float = 0.2
## Falling below this height (relative to the road surface) kills the player.
@export var fall_death_height: float = -4.0
## Half length along the track of a jump pad's trigger zone.
@export var pad_half_length: float = 0.6
## Launch performed by jump pads (no tap needed).
@export var pad_launch: ActionDefinition
## Every this many consecutive cue hits charge one shield; a shield absorbs one fatal hit.
@export var shield_combo: int = 16
@export var max_shields: int = 1
@export var actions: Array[ActionDefinition] = []
@export var hazards: Array[HazardDefinition] = []

const JUMP_COLOR: Color = Color(1.0, 0.25, 0.85)
const DODGE_COLOR: Color = Color(1.0, 0.58, 0.15)
const FLIP_COLOR: Color = Color(0.55, 1.0, 0.3)
const CUBE_SIZE: float = 1.0


static func create_default() -> GameplayConfig:
	var config := GameplayConfig.new()
	config.actions = [
		_action(&"jump", ActionDefinition.Kind.JUMP, 1.0, &"spike", 0.5, JUMP_COLOR, &"player.jump"),
		_dodge(config, &"dodge_left", -1.0, &"wall_gap_left"),
		_dodge(config, &"dodge_right", 1.0, &"wall_gap_right"),
		_flip(config),
		_orb(),
	]
	config.pad_launch = _action(&"pad", ActionDefinition.Kind.JUMP, 1.5, &"", 0.0, JUMP_COLOR, &"player.jump")
	config.pad_launch.jump_height = 4.5
	var spike: HazardDefinition = _hazard(&"spike", HazardDefinition.Visual.SPIKE, HazardDefinition.Entrance.RISE,
			2.0, JUMP_COLOR, &"hazard.rise")
	spike.half_length = 0.32
	spike.lateral_half_width = 0.4
	spike.top = 0.85
	spike.visual_length = 1.0
	spike.visual_width = 1.0
	spike.visual_height = 1.15
	var gate: HazardDefinition = _hazard(&"gate", HazardDefinition.Visual.GATE, HazardDefinition.Entrance.UNFOLD,
			3.0, FLIP_COLOR, &"hazard.unfold")
	gate.half_length = 0.35
	gate.lateral_half_width = config.track_width * 0.5 + 1.1
	gate.top = 4.5
	gate.visual_length = 0.4
	gate.visual_width = config.track_width + 0.8
	gate.visual_height = 3.6
	config.hazards = [spike, _wall(config, &"wall_gap_left", 1.0), _wall(config, &"wall_gap_right", -1.0), gate]
	return config


func find_action(action_id: StringName) -> ActionDefinition:
	for action: ActionDefinition in actions:
		if action.id == action_id:
			return action
	return null


## Gravity for falls that start without a jump (walking off a ledge): same as the default jump.
func fall_gravity() -> float:
	var action: ActionDefinition = find_action(default_action)
	if action == null or action.kind != ActionDefinition.Kind.JUMP:
		push_error("GameplayConfig: default action '%s' must be a JUMP" % default_action)
		return 16.0
	return action.gravity()


func find_hazard(hazard_id: StringName) -> HazardDefinition:
	for hazard: HazardDefinition in hazards:
		if hazard.id == hazard_id:
			return hazard
	return null


static func _action(action_id: StringName, kind: ActionDefinition.Kind, duration: float, hazard_id: StringName,
		hazard_offset: float, color: Color, sound: StringName) -> ActionDefinition:
	var action := ActionDefinition.new()
	action.id = action_id
	action.kind = kind
	action.duration_beats = duration
	action.paired_hazard = hazard_id
	action.hazard_beat_offset = hazard_offset
	action.color = color
	action.start_sound = sound
	if kind == ActionDefinition.Kind.JUMP:
		action.jump_height = 2.0
	return action


static func _dodge(config: GameplayConfig, action_id: StringName, side: float, hazard_id: StringName) -> ActionDefinition:
	var dodge: ActionDefinition = _action(action_id, ActionDefinition.Kind.DODGE, 1.25, hazard_id, 0.625,
			DODGE_COLOR, &"player.dodge")
	dodge.lateral_distance = side * config.lane_width
	dodge.transition_fraction = 0.2
	return dodge


static func _flip(config: GameplayConfig) -> ActionDefinition:
	var flip: ActionDefinition = _action(&"flip", ActionDefinition.Kind.FLIP, 2.0, &"gate", 1.0, FLIP_COLOR,
			&"player.flip")
	flip.lateral_distance = config.track_width * 0.5 + 0.7
	flip.flip_depth = config.track_thickness + CUBE_SIZE
	flip.transition_fraction = 0.15
	return flip


## Mid-air jump ring: same arc as a jump, but it can be tapped while airborne.
static func _orb() -> ActionDefinition:
	var orb: ActionDefinition = _action(&"orb", ActionDefinition.Kind.JUMP, 1.0, &"", 0.5, JUMP_COLOR, &"player.jump")
	orb.air_allowed = true
	return orb


## Wall covering the middle lane and the lane on `covered_side` (+1 right / -1 left); the gap is opposite.
static func _wall(config: GameplayConfig, hazard_id: StringName, covered_side: float) -> HazardDefinition:
	var wall: HazardDefinition = _hazard(hazard_id, HazardDefinition.Visual.WALL, HazardDefinition.Entrance.DROP,
			3.0, DODGE_COLOR, &"hazard.drop")
	wall.half_length = 0.45
	wall.lateral_center = covered_side * config.lane_width * 0.5
	wall.lateral_half_width = config.lane_width * 0.98
	wall.top = 3.2
	wall.visual_length = 0.9
	wall.visual_width = config.lane_width * 2.0
	wall.visual_height = 3.2
	return wall


static func _hazard(hazard_id: StringName, visual: HazardDefinition.Visual, entrance: HazardDefinition.Entrance,
		lead: float, color: Color, sound: StringName) -> HazardDefinition:
	var hazard := HazardDefinition.new()
	hazard.id = hazard_id
	hazard.visual = visual
	hazard.entrance = entrance
	hazard.lead_beats = lead
	hazard.color = color
	hazard.landing_sound = sound
	return hazard
