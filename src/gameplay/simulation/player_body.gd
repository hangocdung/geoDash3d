# The player's body over the terrain: its vertical motion, the ground under its box, falls off ledges, jump
# pads and flight sections (gameplay v4: lifted in at the start, no ground while flying, a fall at the end).
# RunSimulation decides what contacts mean (landing, death, shields) and emits the signals.
# Related: run_simulation.gd, vertical_motion.gd, src/gameplay/track/terrain.gd
class_name PlayerBody
extends RefCounted

enum Flight { NONE, ENTERED, EXITED }

var motion := VerticalMotion.new()
## Inside a flight section: no ground under the player, taps flap.
var flying: bool = false
var _chart: LevelChart
var _config: GameplayConfig
var _fall_gravity: float = 0.0
var _pad_cursor: int = 0
var _fly_cursor: int = 0


func _init(level_chart: LevelChart, gameplay_config: GameplayConfig, start_beat: float) -> void:
	_chart = level_chart
	_config = gameplay_config
	_fall_gravity = gameplay_config.fall_gravity()
	while _fly_cursor < level_chart.fly_ranges.size() and level_chart.fly_ranges[_fly_cursor].y <= start_beat:
		_fly_cursor += 1
	var support: float = support_at(start_beat)
	motion.reset(start_beat, 0.0 if Terrain.is_gap(support) else support)
	if Terrain.is_gap(support):
		fall(start_beat)


## Highest ground under the player's box at `beat` (Terrain.GAP if there is none, or while flying).
func support_at(beat: float) -> float:
	return Terrain.GAP if flying else support_under(_chart, _config, beat)


## Same as support_at, for read-only code without a PlayerBody (LandingPredictor).
static func support_under(chart: LevelChart, config: GameplayConfig, beat: float) -> float:
	var distance: float = chart.distance_at(beat)
	return chart.terrain.support_height(distance - config.player_half_length, distance + config.player_half_length)


func launch(action: ActionDefinition, beat: float) -> void:
	motion.launch(action, beat, action.launch_velocity(), action.gravity())


func fall(beat: float) -> void:
	motion.launch(null, beat, 0.0, _fall_gravity)


## Ground contact at grid `beat`. Running off a ledge starts a fall here, so LEFT_GROUND is never returned.
func step(beat: float, support: float) -> VerticalMotion.Contact:
	var contact: VerticalMotion.Contact = motion.step(beat, support, _config.step_snap, _config.fall_death_height)
	if contact == VerticalMotion.Contact.LEFT_GROUND:
		fall(beat)
		return VerticalMotion.Contact.NONE
	return contact


## Enters or leaves a flight section at grid `beat`: the lift into the air at its start (from wherever the player
## is), and at its end the same arc goes on under normal gravity until the landing.
func update_flight(beat: float) -> Flight:
	if _fly_cursor >= _chart.fly_ranges.size():
		return Flight.NONE
	var section: Vector2 = _chart.fly_ranges[_fly_cursor]
	if not flying and beat >= section.x:
		flying = true
		launch(_config.fly_entry, section.x)
		return Flight.ENTERED
	if flying and beat >= section.y:
		flying = false
		_fly_cursor += 1
		motion.launch(null, section.y, motion.velocity_at(section.y), _fall_gravity)
		return Flight.EXITED
	return Flight.NONE


## Flying into the corridor's spikes at grid `beat` (false outside flight or before the corridor is built).
func hits_corridor(beat: float) -> bool:
	if not flying or _chart.flight == null:
		return false
	var height: float = motion.height_at(beat)
	return _chart.flight.hits(_chart.distance_at(beat), height + _config.player_bottom, height + _config.player_top)


## Puts the body back on the perfect run's ground or arc at `beat` (a shield). Returns the airtime when that lands
## it, -1 when it does not, NAN when there is no perfect run to go back to.
func restore_reference(beat: float) -> float:
	var reference: VerticalMotion = _chart.reference_motion_at(beat)
	if reference == null:
		return NAN
	var was_airborne: bool = motion.airborne
	var take_off: float = motion.take_off_beat
	motion.restore(reference, beat)
	return beat - take_off if was_airborne and not motion.airborne else -1.0


## Launches the player off a jump pad its feet touch while grounded; returns the launch beat, or NAN.
func check_pads(beat: float) -> float:
	var distance: float = _chart.distance_at(beat)
	var pads: Array[ChartItems.PadPlacement] = _chart.pads
	while _pad_cursor < pads.size() \
			and pads[_pad_cursor].distance + _config.pad_half_length < distance - _config.player_half_length:
		_pad_cursor += 1
	if motion.airborne or _pad_cursor >= pads.size():
		return NAN
	var trigger_distance: float = pads[_pad_cursor].distance - _config.pad_half_length - _config.player_half_length
	if distance < trigger_distance:
		return NAN
	_pad_cursor += 1
	var launch_beat: float = maxf(_chart.beat_at_distance(trigger_distance), motion.grounded_since)
	launch(_config.pad_launch, launch_beat)
	return launch_beat
