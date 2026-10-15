# Best results per chart, kept in user://scores.cfg (one section per chart file name): best score, furthest
# progress, best max combo and whether the level was ever completed. Only real runs are submitted (the level
# decides: no practice, autoplay, attract, capture or invincible runs).
# Related: src/presentation/level/run_records.gd, src/ui/menu/song_list_panel.gd
class_name HighScores
extends RefCounted

const DEFAULT_PATH: String = "user://scores.cfg"

## Tests point this at a scratch file.
static var path: String = DEFAULT_PATH


class Record:
	var score: int = 0
	## 0..1, furthest point reached (1 = completed).
	var progress: float = 0.0
	var max_combo: int = 0
	var completed: bool = false

	func has_any() -> bool:
		return score > 0 or progress > 0.0


static func best(chart_path: String) -> Record:
	var record := Record.new()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return record
	var section: String = chart_path.get_file()
	record.score = int(file.get_value(section, "score", 0))
	record.progress = float(file.get_value(section, "progress", 0.0))
	record.max_combo = int(file.get_value(section, "max_combo", 0))
	record.completed = bool(file.get_value(section, "completed", false))
	return record


## Merges a finished (or died) run into the chart's record; returns the previous record for "new best" notes.
static func submit(chart_path: String, score: int, progress: float, max_combo: int, completed: bool) -> Record:
	var previous: Record = best(chart_path)
	var file := ConfigFile.new()
	var error: Error = file.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("HighScores: cannot read '%s' (%s)" % [path, error_string(error)])
		return previous
	var section: String = chart_path.get_file()
	file.set_value(section, "score", maxi(previous.score, score))
	file.set_value(section, "progress", maxf(previous.progress, clampf(progress, 0.0, 1.0)))
	file.set_value(section, "max_combo", maxi(previous.max_combo, max_combo))
	file.set_value(section, "completed", previous.completed or completed)
	error = file.save(path)
	if error != OK:
		push_error("HighScores: cannot save '%s' (%s)" % [path, error_string(error)])
	return previous
