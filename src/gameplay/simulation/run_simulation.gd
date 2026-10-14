# Deterministic run state: player motion over the terrain, tap handling, misses and collisions, in beats.
# Same chart + same tap beats ⇒ same result, independent of frame rate (fixed collision grid).
# Related: action_resolver.gd, hazard_checker.gd, vertical_motion.gd, src/presentation/level/level_runner.gd
class_name RunSimulation
extends RefCounted

signal action_started(action: ActionDefinition, start_beat: float, cue_index: int)
## Dodge / flip ended (jumps end with `player_landed`).
signal action_finished(action: ActionDefinition, end_beat: float)
## Touched down after a jump, orb, pad or fall; `airtime_beats` counts from leaving the ground.
signal player_landed(beat: float, airtime_beats: float)
signal cue_judged(cue_index: int, grade: Judgement.Grade, error_sec: float)
signal hazard_hit(hazard_index: int, beat: float)
signal player_died(hazard_index: int, beat: float)
signal run_completed(beat: float)
## Every tap near a cue (±TAP_TIMING_RANGE_SEC), hit or not: tap − cue in seconds (positive = late).
signal tap_timed(error_sec: float)

const TAP_TIMING_RANGE_SEC: float = 0.4
## Hazard index reported when the terrain kills the player (side of a ledge, fall into a gap).
const TERRAIN_HIT: int = -2

var chart: LevelChart
var config: GameplayConfig
## Practice/authoring: hazards are recorded in `hit_hazards` instead of killing the player.
var invincible: bool = false
var current_beat: float = 0.0
var is_dead: bool = false
var is_completed: bool = false
var tap_log: PackedFloat64Array = []
var hit_hazards: PackedInt32Array = []
## Count per Judgement.Grade value.
var grade_counts: PackedInt32Array = [0, 0, 0, 0]

var _resolver: ActionResolver
var _checker: HazardChecker
var _motion := VerticalMotion.new()
var _fall_gravity: float = 0.0
## Dodge or flip in progress (fixed duration); jumps live in _motion.
var _active_action: ActionDefinition = null
var _active_start_beat: float = 0.0
var _buffered_tap_beat: float = NAN
var _grid_index: int = 0
var _pad_cursor: int = 0


func _init(level_chart: LevelChart, gameplay_config: GameplayConfig, start_beat: float) -> void:
	chart = level_chart
	config = gameplay_config
	current_beat = start_beat
	_grid_index = floori(start_beat / config.simulation_step_beats)
	_resolver = ActionResolver.new(chart.cues, chart.tempo, config.cue_window_sec)
	_resolver.skip_before(start_beat)
	_checker = HazardChecker.new(chart.hazards)
	_fall_gravity = config.fall_gravity()
	var support: float = _support_at(start_beat)
	_motion.reset(start_beat, 0.0 if Terrain.is_gap(support) else support)
	if Terrain.is_gap(support):
		_motion.launch(null, start_beat, 0.0, _fall_gravity)


func tap(beat: float) -> void:
	if is_dead:
		return
	var tap_beat: float = maxf(beat, current_beat)
	advance_to(tap_beat)
	if is_dead:
		return
	tap_log.append(tap_beat)
	var timing_error: float = _resolver.nearest_cue_error_sec(tap_beat, TAP_TIMING_RANGE_SEC)
	if not is_nan(timing_error):
		tap_timed.emit(timing_error)
	if _active_action != null:
		var action_end: float = _active_start_beat + _active_action.duration_beats
		if chart.tempo.seconds_between(tap_beat, action_end) <= config.input_buffer_sec:
			_buffered_tap_beat = tap_beat
		return
	if _motion.airborne:
		# In the air only a jump orb can be tapped; any other tap waits for the landing (input buffer).
		var cue_index: int = _resolver.match_tap(tap_beat)
		if cue_index != ActionResolver.NO_CUE and _resolver.cue(cue_index).action.air_allowed:
			_buffered_tap_beat = NAN
			_perform_tap(tap_beat, tap_beat)
		else:
			_buffered_tap_beat = tap_beat
		return
	_perform_tap(tap_beat, tap_beat)


func advance_to(target_beat: float) -> void:
	var step: float = config.simulation_step_beats
	while not is_dead:
		var grid_beat: float = float(_grid_index + 1) * step
		if grid_beat > target_beat:
			break
		_grid_index += 1
		current_beat = grid_beat
		_simulate_step(grid_beat)
	if not is_dead and target_beat > current_beat:
		current_beat = target_beat


## Offset from the track surface: x = lateral (+ = right), y = height of the player's lower edge.
func player_offset_at(beat: float) -> Vector2:
	var offset := Vector2(0.0, _motion.height_at(beat))
	if _active_action != null:
		offset += _active_action.offset_at(action_progress_at(beat))
	return offset


func player_height_at(beat: float) -> float:
	return player_offset_at(beat).y


## 0..1 progress of the active action at `beat` (jumps: of their flat-ground duration), or -1 when idle.
func action_progress_at(beat: float) -> float:
	if _active_action != null:
		return clampf((beat - _active_start_beat) / _active_action.duration_beats, 0.0, 1.0)
	if _motion.airborne and _motion.launch_action != null:
		return clampf((beat - _motion.launch_beat) / _motion.launch_action.duration_beats, 0.0, 1.0)
	return -1.0


## Dodge/flip in progress, else the action that launched the current arc (null while standing or falling).
func active_action() -> ActionDefinition:
	if _active_action != null:
		return _active_action
	return _motion.launch_action if _motion.airborne else null


func is_airborne() -> bool:
	return _motion.airborne


## Beats since the player left the ground, or -1 while grounded.
func air_beats_at(beat: float) -> float:
	return _motion.air_beats_at(beat)


func player_distance_at(beat: float) -> float:
	return chart.distance_at(beat)


func _perform_tap(tap_beat: float, start_beat: float) -> void:
	var cue_index: int = _resolver.match_tap(tap_beat)
	var action: ActionDefinition
	if cue_index != ActionResolver.NO_CUE:
		_resolver.consume(cue_index)
		action = _resolver.cue(cue_index).action
		var error_sec: float = _resolver.timing_error_sec(cue_index, tap_beat)
		var grade: Judgement.Grade = Judgement.grade_for_error(error_sec, config)
		grade_counts[grade] += 1
		cue_judged.emit(cue_index, grade, error_sec)
	else:
		action = config.find_action(config.default_action)
		if action == null:
			push_error("RunSimulation: default action '%s' is not defined" % config.default_action)
			return
	if action.kind == ActionDefinition.Kind.JUMP:
		_motion.launch(action, start_beat, action.launch_velocity(), action.gravity())
	else:
		_active_action = action
		_active_start_beat = start_beat
	action_started.emit(action, start_beat, cue_index)


func _simulate_step(beat: float) -> void:
	_finish_action_if_due(beat)
	for missed_index: int in _resolver.collect_missed(beat):
		grade_counts[Judgement.Grade.MISS] += 1
		cue_judged.emit(missed_index, Judgement.Grade.MISS, NAN)
	if not _update_motion(beat):
		return
	_check_pads(beat)
	var offset: Vector2 = player_offset_at(beat)
	var hazard_index: int = _checker.find_collision(chart.distance_at(beat), config.player_half_length,
			Vector2(offset.x - config.player_half_width, offset.x + config.player_half_width),
			Vector2(offset.y + config.player_bottom, offset.y + config.player_top), active_action(), hit_hazards)
	if hazard_index != HazardChecker.NO_HAZARD:
		if invincible:
			hit_hazards.append(hazard_index)
			hazard_hit.emit(hazard_index, beat)
		else:
			_die(hazard_index, beat)
			return
	if not is_completed and beat >= chart.end_beat:
		is_completed = true
		run_completed.emit(beat)


## Ground contact for this grid step. Returns false when the player died.
func _update_motion(beat: float) -> bool:
	var support: float = _support_at(beat)
	match _motion.step(beat, support, config.step_snap, config.fall_death_height):
		VerticalMotion.Contact.LEFT_GROUND:
			_motion.launch(null, beat, 0.0, _fall_gravity)
		VerticalMotion.Contact.LANDED:
			_on_landed()
		VerticalMotion.Contact.HIT_SIDE:
			if not invincible:
				_die(TERRAIN_HIT, beat)
				return false
			hazard_hit.emit(TERRAIN_HIT, beat)
			var was_airborne: bool = _motion.airborne
			_motion.land(beat, support)
			if was_airborne:
				_on_landed()
		VerticalMotion.Contact.FELL:
			if not invincible:
				_die(TERRAIN_HIT, beat)
				return false
	return true


func _on_landed() -> void:
	var landing_beat: float = _motion.grounded_since
	player_landed.emit(landing_beat, _motion.last_airtime)
	if is_nan(_buffered_tap_beat):
		return
	var buffered: float = _buffered_tap_beat
	_buffered_tap_beat = NAN
	if chart.tempo.seconds_between(buffered, landing_beat) <= config.input_buffer_sec:
		_perform_tap(buffered, maxf(buffered, landing_beat))


## Jump pads launch the player (no tap) once its feet touch the pad while on the ground.
func _check_pads(beat: float) -> void:
	var distance: float = chart.distance_at(beat)
	while _pad_cursor < chart.pads.size() \
			and chart.pads[_pad_cursor].distance + config.pad_half_length < distance - config.player_half_length:
		_pad_cursor += 1
	if _motion.airborne or _pad_cursor >= chart.pads.size():
		return
	var pad: ChartItems.PadPlacement = chart.pads[_pad_cursor]
	var trigger_distance: float = pad.distance - config.pad_half_length - config.player_half_length
	if distance < trigger_distance:
		return
	_pad_cursor += 1
	var launch_beat: float = maxf(chart.beat_at_distance(trigger_distance), _motion.grounded_since)
	var launch: ActionDefinition = config.pad_launch
	_motion.launch(launch, launch_beat, launch.launch_velocity(), launch.gravity())
	action_started.emit(launch, launch_beat, ActionResolver.NO_CUE)


func _support_at(beat: float) -> float:
	var distance: float = chart.distance_at(beat)
	return chart.terrain.support_height(distance - config.player_half_length, distance + config.player_half_length)


func _die(hazard_index: int, beat: float) -> void:
	is_dead = true
	player_died.emit(hazard_index, beat)


func _finish_action_if_due(beat: float) -> void:
	if _active_action == null:
		return
	var end_beat: float = _active_start_beat + _active_action.duration_beats
	if beat < end_beat:
		return
	var finished: ActionDefinition = _active_action
	_active_action = null
	action_finished.emit(finished, end_beat)
	# While falling, a buffered tap waits for the landing instead.
	if not is_nan(_buffered_tap_beat) and not _motion.airborne:
		var buffered: float = _buffered_tap_beat
		_buffered_tap_beat = NAN
		_perform_tap(buffered, end_beat)
