# Connects a level's runs to HighScores: decides whether a run counts (normal play only), submits it when it
# completes or dies and words the results ("NEW BEST", best progress for the next attempt's toast) and the songs a
# result opens (SongUnlocks, GD3-242).
# Related: src/core/high_scores.gd, src/presentation/level/level_runner.gd, src/gameplay/simulation/score_keeper.gd
class_name RunRecords
extends RefCounted

## Accuracy needed for each rank, best first.
const RANKS: Dictionary[float, String] = {0.95: "S", 0.85: "A", 0.7: "B"}

var _chart_path: String
var _counts: bool
var _max_score: int
## Song order and titles, read once per level (unlock checks after each submitted run).
var _ordered: PackedStringArray = []
var _titles: Dictionary[String, String] = {}
var _open: Dictionary[String, bool] = {}
## Listed songs that are not downloaded yet: they never block unlocks and NEXT SONG skips them (GD3-300).
var _pending: Dictionary[String, bool] = {}


func _init(chart_path: String, options: LaunchOptions, chart: LevelChart, config: GameplayConfig) -> void:
	_chart_path = chart_path
	_counts = not (options.practice or options.autoplay or options.attract_mode or options.invincible
			or options.is_capture_run() or not is_equal_approx(options.playback_rate, 1.0))
	_max_score = ScoreKeeper.max_score(chart.cues.size(), config)
	if _counts:
		var entries: Array[SongCatalog.Entry] = SongCatalog.list_songs()
		for entry: SongCatalog.Entry in entries:
			_ordered.append(entry.path)
			_titles[entry.path] = entry.title
		_pending = SongCatalog.pending(entries)
		_open = SongUnlocks.unlocked(_ordered, _pending)


func counts() -> bool:
	return _counts


func best() -> HighScores.Record:
	return HighScores.best(_chart_path)


## The level-complete menu: title, score lines (on_completed), grade counts and max combo.
func completed_text(simulation: RunSimulation, practice: bool) -> String:
	var counts: PackedInt32Array = simulation.grade_counts
	return "%s\n%s\nPERFECT %d   GREAT %d   GOOD %d   MISS %d\n%s" % [
			Locale.t("PRACTICE COMPLETE" if practice else "LEVEL COMPLETE"), on_completed(simulation), counts[0],
			counts[1], counts[2], counts[3], Locale.t("MAX COMBO %d") % simulation.streak.max_combo]


## Rank of a finished run by accuracy (score / best possible score): S, A, B or C.
func rank(simulation: RunSimulation) -> String:
	var accuracy: float = float(simulation.score.score) / float(maxi(_max_score, 1))
	for bound: float in RANKS:
		if accuracy >= bound:
			return RANKS[bound]
	return "C"


## The next open, downloaded song after this one (SongCatalog order), "" when there is none or the run did not count.
func next_song() -> String:
	var index: int = _ordered.find(_chart_path)
	if index < 0:
		return ""
	var open: Dictionary[String, bool] = SongUnlocks.unlocked(_ordered, _pending)
	for path: String in _ordered.slice(index + 1):
		if open.has(path) and not _pending.has(path):
			return path
	return ""


## Lines for the level-complete menu (score, accuracy, best); submits the run when it counts.
func on_completed(simulation: RunSimulation) -> String:
	var score: int = simulation.score.score
	var accuracy: float = 100.0 * float(score) / float(maxi(_max_score, 1))
	var lines: String = Locale.t("SCORE %s  ·  %.1f%%") % [grouped(score), accuracy]
	if not _counts:
		return lines
	var previous: HighScores.Record = HighScores.submit(_chart_path, score, 1.0, simulation.streak.max_combo, true)
	var best_line: String = Locale.t("NEW BEST!") if score > previous.score \
			else Locale.t("BEST %s") % grouped(previous.score)
	return "%s\n%s%s" % [lines, best_line, _unlock_note("\n")]


## Submits a run that died at `progress` (0..1); returns a note for the next attempt ("" if nothing to say).
func on_died(simulation: RunSimulation, progress: float) -> String:
	if not _counts:
		return ""
	var previous: HighScores.Record = HighScores.submit(_chart_path, simulation.score.score, progress,
			simulation.streak.max_combo, false)
	if progress > previous.progress + 0.005:
		return Locale.t("NEW BEST %d%%") % int(floorf(progress * 100.0)) + _unlock_note("  ·  ")
	return Locale.t("BEST %d%%") % int(floorf(maxf(previous.progress, progress) * 100.0))


## "UNLOCKED: TITLE" for songs the last submitted run opened ("" when none), after `separator`; logs each unlock.
func _unlock_note(separator: String) -> String:
	if _ordered.is_empty():
		return ""
	var now: Dictionary[String, bool] = SongUnlocks.unlocked(_ordered, _pending)
	var opened: PackedStringArray = []
	for path: String in now:
		if not _open.has(path):
			opened.append(_titles.get(path, path.get_file()).to_upper())
			Telemetry.log_event("song_unlock", {"song_id": SongCatalog.song_id(path), "by": "progress"})
	_open = now
	if opened.is_empty():
		return ""
	return separator + Locale.t("UNLOCKED: %s") % ", ".join(opened)


## 1234567 → "1,234,567".
static func grouped(value: int) -> String:
	var digits: String = str(absi(value))
	var result: String = ""
	while digits.length() > 3:
		result = "," + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + result
