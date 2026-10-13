# Deterministic run state: player motion, tap handling, misses and collisions, all in beats.
# Same chart + same tap beats ⇒ same result, independent of frame rate (fixed collision grid).
# Related: action_resolver.gd, hazard_checker.gd, src/presentation/level/level_runner.gd
class_name RunSimulation
extends RefCounted

signal action_started(action: ActionDefinition, start_beat: float, cue_index: int)
signal action_finished(action: ActionDefinition, end_beat: float)
signal cue_judged(cue_index: int, grade: Judgement.Grade, error_sec: float)
signal hazard_hit(hazard_index: int, beat: float)
signal player_died(hazard_index: int, beat: float)
signal run_completed(beat: float)

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
var _active_action: ActionDefinition = null
var _active_start_beat: float = 0.0
var _buffered_tap_beat: float = NAN
var _grid_index: int = 0


func _init(level_chart: LevelChart, gameplay_config: GameplayConfig, start_beat: float) -> void:
	chart = level_chart
	config = gameplay_config
	current_beat = start_beat
	_grid_index = floori(start_beat / config.simulation_step_beats)
	_resolver = ActionResolver.new(chart.cues, chart.tempo, config.cue_window_sec)
	_resolver.skip_before(start_beat)
	_checker = HazardChecker.new(chart.hazards)


func tap(beat: float) -> void:
	if is_dead:
		return
	var tap_beat: float = maxf(beat, current_beat)
	advance_to(tap_beat)
	if is_dead:
		return
	tap_log.append(tap_beat)
	if _active_action != null:
		var action_end: float = _active_start_beat + _active_action.duration_beats
		if chart.tempo.seconds_between(tap_beat, action_end) <= config.input_buffer_sec:
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


func player_height_at(beat: float) -> float:
	if _active_action == null:
		return 0.0
	return _active_action.height_at(action_progress_at(beat))


## 0..1 progress of the active action at `beat`, or -1 when idle.
func action_progress_at(beat: float) -> float:
	if _active_action == null:
		return -1.0
	return clampf((beat - _active_start_beat) / _active_action.duration_beats, 0.0, 1.0)


func active_action() -> ActionDefinition:
	return _active_action


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
	_active_action = action
	_active_start_beat = start_beat
	action_started.emit(action, start_beat, cue_index)


func _simulate_step(beat: float) -> void:
	_finish_action_if_due(beat)
	for missed_index: int in _resolver.collect_missed(beat):
		grade_counts[Judgement.Grade.MISS] += 1
		cue_judged.emit(missed_index, Judgement.Grade.MISS, NAN)
	var height: float = player_height_at(beat)
	var hazard_index: int = _checker.find_collision(chart.distance_at(beat), config.player_half_length,
			height + config.player_bottom, height + config.player_top, _active_action, hit_hazards)
	if hazard_index != HazardChecker.NO_HAZARD:
		if invincible:
			hit_hazards.append(hazard_index)
			hazard_hit.emit(hazard_index, beat)
		else:
			is_dead = true
			player_died.emit(hazard_index, beat)
			return
	if not is_completed and beat >= chart.end_beat:
		is_completed = true
		run_completed.emit(beat)


func _finish_action_if_due(beat: float) -> void:
	if _active_action == null:
		return
	var end_beat: float = _active_start_beat + _active_action.duration_beats
	if beat < end_beat:
		return
	var finished: ActionDefinition = _active_action
	_active_action = null
	action_finished.emit(finished, end_beat)
	if not is_nan(_buffered_tap_beat):
		var buffered: float = _buffered_tap_beat
		_buffered_tap_beat = NAN
		_perform_tap(buffered, end_beat)
