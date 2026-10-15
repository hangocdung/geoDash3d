# The playable songs: every *.chart.json in assets/music except *.classic.chart.json (kept for comparisons), easiest
# first (ChartDifficulty), read cheaply from the JSON (the level does the full validation). Used by the song list and
# by SongUnlocks. Related: src/ui/menu/song_list_panel.gd, src/core/song_unlocks.gd
class_name SongCatalog
extends RefCounted

const MUSIC_DIRECTORY: String = "res://assets/music"


class Entry:
	var path: String
	var id: String
	var title: String
	var bpm: float
	var length_sec: float
	var difficulty: float


static func list_songs() -> Array[Entry]:
	var entries: Array[Entry] = []
	for file_name: String in DirAccess.get_files_at(MUSIC_DIRECTORY):
		if not file_name.ends_with(".chart.json") or file_name.ends_with(".classic.chart.json"):
			continue
		var path: String = MUSIC_DIRECTORY.path_join(file_name)
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) != TYPE_DICTIONARY:
			push_error("SongCatalog: cannot read chart '%s'" % path)
			continue
		var chart: Dictionary = data
		var tempo: Array = chart.get("tempo", [])
		var entry := Entry.new()
		entry.path = path
		entry.id = song_id(path)
		entry.title = str(chart.get("title", file_name))
		entry.bpm = float((tempo[0] as Dictionary).get("bpm", 120.0)) if not tempo.is_empty() else 120.0
		entry.length_sec = float(chart.get("end_beat", 0.0)) * 60.0 / maxf(entry.bpm, 1.0)
		entry.difficulty = ChartDifficulty.score(chart)
		entries.append(entry)
	entries.sort_custom(func(a: Entry, b: Entry) -> bool:
		if not is_equal_approx(a.difficulty, b.difficulty):
			return a.difficulty < b.difficulty
		return a.title.naturalnocasecmp_to(b.title) < 0)
	return entries


## "res://assets/music/fault_line.chart.json" → "fault_line".
static func song_id(chart_path: String) -> String:
	return chart_path.get_file().trim_suffix(".chart.json")
