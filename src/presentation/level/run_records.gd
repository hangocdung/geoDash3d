# Connects a level's runs to HighScores: decides whether a run counts (normal play only), submits it when it
# completes or dies and words the results ("NEW BEST", best progress for the next attempt's toast).
# Related: src/core/high_scores.gd, src/presentation/level/level_runner.gd, src/gameplay/simulation/score_keeper.gd
class_name RunRecords
extends RefCounted

var _chart_path: String
var _counts: bool
var _max_score: int


func _init(chart_path: String, options: LaunchOptions, chart: LevelChart, config: GameplayConfig) -> void:
	_chart_path = chart_path
	_counts = not (options.practice or options.autoplay or options.attract_mode or options.invincible
			or options.is_capture_run() or not is_equal_approx(options.playback_rate, 1.0))
	_max_score = ScoreKeeper.max_score(chart.cues.size(), config)


func counts() -> bool:
	return _counts


func best() -> HighScores.Record:
	return HighScores.best(_chart_path)


## The level-complete menu: title, score lines (on_completed), grade counts and max combo.
func completed_text(simulation: RunSimulation, practice: bool) -> String:
	var counts: PackedInt32Array = simulation.grade_counts
	return "%s\n%s\nPERFECT %d   GREAT %d   GOOD %d   MISS %d\nMAX COMBO %d" % [
			"PRACTICE COMPLETE" if practice else "LEVEL COMPLETE", on_completed(simulation), counts[0], counts[1],
			counts[2], counts[3], simulation.streak.max_combo]


## Lines for the level-complete menu (score, accuracy, best); submits the run when it counts.
func on_completed(simulation: RunSimulation) -> String:
	var score: int = simulation.score.score
	var accuracy: float = 100.0 * float(score) / float(maxi(_max_score, 1))
	var lines: String = "SCORE %s  ·  %.1f%%" % [grouped(score), accuracy]
	if not _counts:
		return lines
	var previous: HighScores.Record = HighScores.submit(_chart_path, score, 1.0, simulation.streak.max_combo, true)
	if score > previous.score:
		return lines + "\nNEW BEST!"
	return lines + "\nBEST %s" % grouped(previous.score)


## Submits a run that died at `progress` (0..1); returns a note for the next attempt ("" if nothing to say).
func on_died(simulation: RunSimulation, progress: float) -> String:
	if not _counts:
		return ""
	var previous: HighScores.Record = HighScores.submit(_chart_path, simulation.score.score, progress,
			simulation.streak.max_combo, false)
	if progress > previous.progress + 0.005:
		return "NEW BEST %d%%" % int(floorf(progress * 100.0))
	return "BEST %d%%" % int(floorf(maxf(previous.progress, progress) * 100.0))


## 1234567 → "1,234,567".
static func grouped(value: int) -> String:
	var digits: String = str(absi(value))
	var result: String = ""
	while digits.length() > 3:
		result = "," + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + result
