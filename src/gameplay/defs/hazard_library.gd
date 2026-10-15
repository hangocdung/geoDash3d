# Every hazard a chart can name: collision boxes in track space, look and entrance (see gameplay_v2/v3.md).
# Hitboxes are slightly smaller than visuals; variants keep the way through of the hazard they stand in for.
# Related: src/gameplay/defs/gameplay_config.gd, src/gameplay/defs/hazard_definition.gd
class_name HazardLibrary
extends RefCounted

const JUMP_COLOR: Color = GameplayConfig.JUMP_COLOR
const DODGE_COLOR: Color = GameplayConfig.DODGE_COLOR
const FLIP_COLOR: Color = GameplayConfig.FLIP_COLOR
const FLY_COLOR: Color = GameplayConfig.FLY_COLOR


static func create_all(config: GameplayConfig) -> Array[HazardDefinition]:
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
	gate.face = HazardDefinition.Face.TOP
	var hazards: Array[HazardDefinition] = [spike, _wall(config, &"wall_gap_left", 1.0),
			_wall(config, &"wall_gap_right", -1.0), gate, _spike_row(&"spike_double", 2, 0.75, 0.75, 1.8, 1.05),
			_spike_row(&"spike_triple", 3, 1.05, 0.65, 2.4, 0.9), _saw(), _ceiling(config)]
	# GD3-104 variants: same ways through (and the same or a looser hitbox) as the hazard they stand in for.
	hazards.append_array([_laser_fence(config), _pendulum(), _spike_mine(), _crusher(config),
			_wall(config, &"laser_gap_left", 1.0, HazardDefinition.Visual.LASER_WALL),
			_wall(config, &"laser_gap_right", -1.0, HazardDefinition.Visual.LASER_WALL), _ring_gate(gate)])
	# GD3-106: hazards of the roll (full turn around the track), blocking the whole road like the gate.
	hazards.append_array([_mace_sweep(gate), _falling_block(gate)])
	# GD3-112: the gate that closes an underside run hangs under the track (flip_up's hazard).
	var gate_under: HazardDefinition = gate.duplicate() as HazardDefinition
	gate_under.id = &"gate_under"
	gate_under.face = HazardDefinition.Face.UNDERSIDE
	hazards.append(gate_under)
	# Gameplay v4 (GD3-285): new looks on the existing ways through, and the flight's floating mine.
	hazards.append_array([_piston_spikes(), _rolling_ball(), _sliding_wall(config, &"sliding_wall_left", 1.0),
			_sliding_wall(config, &"sliding_wall_right", -1.0), _air_mine(config)])
	_restyle_entrances(hazards)
	return hazards


## Livelier entrances for older hazards (looks only): saws spin down, mines pop up, laser walls slide in.
static func _restyle_entrances(hazards: Array[HazardDefinition]) -> void:
	for hazard: HazardDefinition in hazards:
		match hazard.id:
			&"saw":
				hazard.entrance = HazardDefinition.Entrance.SPIRAL
			&"spike_mine":
				hazard.entrance = HazardDefinition.Entrance.BEAT_POP
			&"laser_gap_left", &"laser_gap_right":
				hazard.entrance = HazardDefinition.Entrance.SWEEP


## Two spikes pumping with the beat: spike_double's hitbox (they are fully up whenever the player can reach them).
static func _piston_spikes() -> HazardDefinition:
	var piston: HazardDefinition = _spike_row(&"piston_spikes", 2, 0.75, 0.75, 1.8, 1.05)
	piston.visual = HazardDefinition.Visual.PISTON
	piston.entrance = HazardDefinition.Entrance.BEAT_POP
	return piston


## Spiked ball rolling at the player; its hitbox waits where they meet (a spike-sized box, a little taller).
static func _rolling_ball() -> HazardDefinition:
	var ball: HazardDefinition = _hazard(&"rolling_ball", HazardDefinition.Visual.ROLLING_BALL,
			HazardDefinition.Entrance.DROP, 2.0, JUMP_COLOR, &"hazard.drop")
	ball.half_length = 0.4
	ball.lateral_half_width = 0.45
	ball.top = 0.9
	ball.visual_length = 1.1
	ball.visual_width = 1.1
	ball.visual_height = 1.1
	return ball


## A wall that slides in to close its lane: the wall's hitbox.
static func _sliding_wall(config: GameplayConfig, hazard_id: StringName, covered_side: float) -> HazardDefinition:
	var wall: HazardDefinition = _wall(config, hazard_id, covered_side)
	wall.entrance = HazardDefinition.Entrance.SWEEP
	return wall


## Mine floating in a flight corridor across the whole width: FlightCorridor lifts it just above (or below) the
## perfect path and widens the corridor around it.
static func _air_mine(config: GameplayConfig) -> HazardDefinition:
	var mine: HazardDefinition = _hazard(&"air_mine", HazardDefinition.Visual.MINE, HazardDefinition.Entrance.BEAT_POP,
			2.0, FLY_COLOR, &"hazard.rise")
	mine.airborne = true
	mine.half_length = 0.35
	mine.lateral_half_width = config.track_width
	mine.top = 0.9
	mine.visual_length = 0.8
	mine.visual_width = 0.8
	mine.visual_height = 0.45
	return mine


## Spiked mace swinging along the track under a tall gantry: it hangs over the road (gate-sized box) exactly
## when the player arrives, so the player rolls under the track.
static func _mace_sweep(gate: HazardDefinition) -> HazardDefinition:
	var mace: HazardDefinition = gate.duplicate() as HazardDefinition
	mace.id = &"mace_sweep"
	mace.visual = HazardDefinition.Visual.MACE_SWEEP
	mace.entrance = HazardDefinition.Entrance.DROP
	mace.landing_sound = &"hazard.drop"
	mace.half_length = 0.5
	mace.visual_length = 3.4
	mace.visual_height = 6.5
	return mace


## Heavy block slamming onto the road across every lane (a gate-sized box, a little longer).
static func _falling_block(gate: HazardDefinition) -> HazardDefinition:
	var block: HazardDefinition = gate.duplicate() as HazardDefinition
	block.id = &"falling_block"
	block.visual = HazardDefinition.Visual.WALL
	block.entrance = HazardDefinition.Entrance.DROP
	block.lead_beats = 2.0
	block.landing_sound = &"hazard.drop"
	block.half_length = 0.6
	block.top = 3.0
	block.visual_length = 1.3
	block.visual_height = 2.8
	return block


## `count` spikes in a row (one jump clears them, with a tighter window); lower than a single spike.
static func _spike_row(hazard_id: StringName, count: int, half_length: float, top: float, length: float,
		height: float) -> HazardDefinition:
	var row: HazardDefinition = _hazard(hazard_id, HazardDefinition.Visual.SPIKE, HazardDefinition.Entrance.RISE,
			2.0, JUMP_COLOR, &"hazard.rise")
	row.repeat = count
	row.half_length = half_length
	row.lateral_half_width = 0.4
	row.top = top
	row.visual_length = length
	row.visual_width = 0.9
	row.visual_height = height
	return row


## Saw blade standing across the middle lane: jumped like a spike.
static func _saw() -> HazardDefinition:
	var saw: HazardDefinition = _hazard(&"saw", HazardDefinition.Visual.SAW, HazardDefinition.Entrance.RISE, 2.0,
			JUMP_COLOR, &"hazard.rise")
	saw.half_length = 0.42
	saw.lateral_half_width = 0.3
	saw.top = 0.85
	saw.visual_length = 1.7
	saw.visual_width = 0.3
	saw.visual_height = 1.1
	return saw


## Spiked slab over the whole road: deadly in the air, harmless on the ground (dive orb patterns).
static func _ceiling(config: GameplayConfig) -> HazardDefinition:
	var ceiling: HazardDefinition = _hazard(&"ceiling", HazardDefinition.Visual.CEILING,
			HazardDefinition.Entrance.DROP, 3.0, JUMP_COLOR, &"hazard.drop")
	ceiling.half_length = 2.4
	ceiling.lateral_half_width = config.track_width * 0.5 + 0.4
	ceiling.bottom = 1.3
	ceiling.top = 4.0
	ceiling.visual_length = 4.8
	ceiling.visual_width = config.track_width + 0.4
	ceiling.visual_height = 2.2
	return ceiling


## Low laser fence across the whole road: a thinner, lower box than a spike (jumped the same way).
static func _laser_fence(config: GameplayConfig) -> HazardDefinition:
	var laser: HazardDefinition = _hazard(&"laser_fence", HazardDefinition.Visual.LASER, HazardDefinition.Entrance.RISE,
			2.0, JUMP_COLOR, &"hazard.rise")
	laser.half_length = 0.15
	laser.lateral_half_width = config.track_width * 0.5 + 0.4
	laser.top = 0.7
	laser.visual_length = 0.2
	laser.visual_width = config.track_width + 0.6
	laser.visual_height = 0.55
	return laser


## Swinging axe: the hitbox is where the blade hangs as the player passes (a spike-sized box).
static func _pendulum() -> HazardDefinition:
	var pendulum: HazardDefinition = _hazard(&"pendulum", HazardDefinition.Visual.PENDULUM,
			HazardDefinition.Entrance.DROP, 3.0, JUMP_COLOR, &"hazard.drop")
	pendulum.half_length = 0.3
	pendulum.lateral_half_width = 0.4
	pendulum.top = 0.85
	pendulum.visual_length = 1.4
	pendulum.visual_width = 4.0
	pendulum.visual_height = 4.2
	return pendulum


## Spiked mine floating just above the road (spike-sized box).
static func _spike_mine() -> HazardDefinition:
	var mine: HazardDefinition = _hazard(&"spike_mine", HazardDefinition.Visual.MINE, HazardDefinition.Entrance.RISE,
			2.0, JUMP_COLOR, &"hazard.rise")
	mine.half_length = 0.3
	mine.lateral_half_width = 0.4
	mine.bottom = 0.1
	mine.top = 0.85
	mine.visual_length = 0.8
	mine.visual_width = 0.8
	mine.visual_height = 0.5
	return mine


## Hydraulic press: the spiked ceiling's hitbox with a heavier look.
static func _crusher(config: GameplayConfig) -> HazardDefinition:
	var crusher: HazardDefinition = _ceiling(config)
	crusher.id = &"crusher"
	crusher.visual = HazardDefinition.Visual.CRUSHER
	return crusher


## Ring gate: the energy gate's hitbox, a ring instead of posts.
static func _ring_gate(gate: HazardDefinition) -> HazardDefinition:
	var ring: HazardDefinition = gate.duplicate() as HazardDefinition
	ring.id = &"ring_gate"
	ring.visual = HazardDefinition.Visual.RING_GATE
	return ring


## Wall covering the middle lane and the lane on `covered_side` (+1 right / -1 left); the gap is opposite.
static func _wall(config: GameplayConfig, hazard_id: StringName, covered_side: float,
		visual: HazardDefinition.Visual = HazardDefinition.Visual.WALL) -> HazardDefinition:
	var wall: HazardDefinition = _hazard(hazard_id, visual, HazardDefinition.Entrance.DROP,
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
