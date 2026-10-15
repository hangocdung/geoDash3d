# The player's body over the terrain: its vertical motion, the ground under its box, falls off ledges and
# jump pads. RunSimulation decides what contacts mean (landing, death, shields) and emits the signals.
# Related: run_simulation.gd, vertical_motion.gd, src/gameplay/track/terrain.gd
class_name PlayerBody
extends RefCounted

var motion := VerticalMotion.new()
var _chart: LevelChart
var _config: GameplayConfig
var _fall_gravity: float = 0.0
var _pad_cursor: int = 0


func _init(level_chart: LevelChart, gameplay_config: GameplayConfig, start_beat: float) -> void:
	_chart = level_chart
	_config = gameplay_config
	_fall_gravity = gameplay_config.fall_gravity()
	var support: float = support_at(start_beat)
	motion.reset(start_beat, 0.0 if Terrain.is_gap(support) else support)
	if Terrain.is_gap(support):
		fall(start_beat)


## Highest ground under the player's box at `beat` (Terrain.GAP if there is none).
func support_at(beat: float) -> float:
	return support_under(_chart, _config, beat)


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
