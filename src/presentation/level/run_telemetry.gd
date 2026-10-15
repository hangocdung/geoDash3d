# One analytics event per run (GD3-231): level_start when an attempt is prepared, level_end when it dies, completes or
# is left (restart / menu), plus new_best and first_clear for runs that count for high scores. Collects the run's
# grades, timing errors, misses and shields from the simulation's signals. Silent in attract, autoplay and captures.
# Each finished attempt also counts its play time toward the next interstitial (Ads).
# Related: src/core/telemetry.gd, src/presentation/level/level_runner.gd, docs/todo.md (event table)
class_name RunTelemetry
extends RefCounted

const MISS_LIST_LENGTH: int = 100

var _active: bool
var _counts_for_records: bool
var _chart: LevelChart
var _chart_path: String
var _song_id: String
var _chart_version: String
var _mode: String
var _attempt: int = 0
var _simulation: RunSimulation
var _start_beat: float = 0.0
var _open: bool = false
var _previous: HighScores.Record
var _errors_ms: PackedFloat32Array = []
var _misses: PackedStringArray = []
var _shields_used: int = 0


func _init(chart_path: String, chart: LevelChart, options: LaunchOptions, counts_for_records: bool) -> void:
	_active = not (options.attract_mode or options.autoplay or options.is_capture_run())
	_counts_for_records = counts_for_records
	_chart = chart
	_chart_path = chart_path
	_song_id = chart_path.get_file().trim_suffix(".chart.json")
	_chart_version = str(chart.revision)
	_mode = "practice" if options.practice else "normal"


## A new attempt on `simulation` from `start_beat`; closes the previous one as "quit" if it was still running.
func bind(simulation: RunSimulation, start_beat: float) -> void:
	if not _active:
		return
	leave()
	_simulation = simulation
	_start_beat = start_beat
	_attempt += 1
	_open = true
	_previous = HighScores.best(_chart_path)
	_errors_ms.clear()
	_misses.clear()
	_shields_used = 0
	simulation.cue_judged.connect(_on_cue_judged)
	simulation.shield_used.connect(func(_hazard: int, _beat: float) -> void: _shields_used += 1)
	simulation.player_died.connect(_on_player_died)
	simulation.run_completed.connect(_on_run_completed)
	Telemetry.log_event("level_start", {"song_id": _song_id, "chart_version": _chart_version, "mode": _mode,
			"attempt": _attempt, "quality_tier": QualityTier.Tier.keys()[UserSettings.quality_tier].to_lower()})


## The player leaves the attempt (restart or back to the menu) before it ended.
func leave() -> void:
	if _open:
		_finish("quit", _simulation.current_beat, {})


func _on_cue_judged(cue_index: int, grade: Judgement.Grade, error_sec: float) -> void:
	if grade == Judgement.Grade.MISS:
		_misses.append(_beat_text(_chart.cues[cue_index].beat))
	else:
		_errors_ms.append(error_sec * 1000.0)


func _on_player_died(hazard_index: int, beat: float) -> void:
	var extra: Dictionary[String, Variant] = {"death_beat": snappedf(beat, 0.01)}
	if hazard_index >= 0:
		extra["hazard_id"] = String(_chart.hazards[hazard_index].hazard.id)
	var next_cue: ChartItems.ActionCue = _cue_at_or_after(beat)
	if next_cue != null:
		extra["death_cue"] = "%s@%s" % [next_cue.action.id, _beat_text(next_cue.beat)]
	_finish("dead", beat, extra)


func _on_run_completed(beat: float) -> void:
	_finish("complete", beat, {})


func _finish(result: String, beat: float, extra: Dictionary[String, Variant]) -> void:
	_open = false
	var counts: PackedInt32Array = _simulation.grade_counts
	var score: int = _simulation.score.score
	var params: Dictionary[String, Variant] = {"song_id": _song_id, "chart_version": _chart_version, "mode": _mode,
			"result": result, "progress_pct": snappedf(_chart.progress_at(beat) * 100.0, 0.1),
			"duration_sec": snappedf(_chart.time_at(beat) - _chart.time_at(_start_beat), 0.1),
			"perfect": counts[Judgement.Grade.PERFECT], "great": counts[Judgement.Grade.GREAT],
			"good": counts[Judgement.Grade.GOOD], "miss": counts[Judgement.Grade.MISS],
			"max_combo": _simulation.streak.max_combo, "score": score, "shields_used": _shields_used,
			"mean_error_ms": snappedf(_mean(_errors_ms), 0.1), "attempt": _attempt,
			"miss_cues": ",".join(_misses).left(MISS_LIST_LENGTH)}
	params.merge(extra)
	Telemetry.log_event("level_end", params)
	Ads.note_play_time(float(params["duration_sec"]))
	# Only finished runs are submitted to the high scores (RunRecords), so only they can set a record.
	if not _counts_for_records or result == "quit":
		return
	if score > _previous.score:
		Telemetry.log_event("new_best", {"song_id": _song_id, "score": score, "attempts": _attempt})
	if result == "complete" and not _previous.completed:
		Telemetry.log_event("first_clear", {"song_id": _song_id, "score": score, "attempts": _attempt})


func _cue_at_or_after(beat: float) -> ChartItems.ActionCue:
	for cue: ChartItems.ActionCue in _chart.cues:
		if cue.beat >= beat - 0.25:
			return cue
	return null


static func _mean(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / maxf(values.size(), 1)


## 8.0 -> "8", 8.25 -> "8.25" (keeps miss lists short).
static func _beat_text(beat: float) -> String:
	return String.num(beat, 3).trim_suffix(".0")
