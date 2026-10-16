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
	var revision: int = 1
	var remote: Dictionary = {}
	var downloaded: bool = true


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
		entry.revision = int(chart.get("chart_revision", 1))
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
	return merge_remote(entries)


## "res://assets/music/fault_line.chart.json" → "fault_line".
static func song_id(chart_path: String) -> String:
	return chart_path.get_file().trim_suffix(".chart.json")


## Paths of `entries` listed by the remote manifest but not downloaded yet (SongUnlocks skips them, GD3-300).
static func pending(entries: Array[Entry]) -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	for entry: Entry in entries:
		if not entry.downloaded:
			result[entry.path] = true
	return result


static func merge_remote(entries: Array[Entry]) -> Array[Entry]:
	var by_id: Dictionary[String, Entry] = {}
	for entry: Entry in entries:
		by_id[entry.id] = entry
	for song: Dictionary in ContentCatalog.songs():
		var id: String = str(song["id"])
		if not bool(song.get("enabled", true)):
			by_id.erase(id)
			continue
		if not ContentManifest.compatible(str(song.get("min_app_version", "1.0.0"))):
			continue
		var version: int = int(song["version"])
		if by_id.has(id) and by_id[id].revision >= version:
			by_id[id].remote = song
			continue
		var entry := Entry.new()
		entry.path = ContentCatalog.chart_path(song)
		entry.id = id
		entry.title = str(song.get("title", id))
		entry.bpm = float(song.get("bpm", 120.0))
		entry.length_sec = float(song.get("length", 0.0))
		entry.difficulty = float(song.get("difficulty", 0.0))
		entry.revision = version
		entry.remote = song
		entry.downloaded = ContentCatalog.installed(song)
		# Keep a playable bundled copy until an update has finished installing.
		if by_id.has(id) and not entry.downloaded:
			by_id[id].remote = song
		else:
			by_id[id] = entry
	var result: Array[Entry] = by_id.values()
	result.sort_custom(func(a: Entry, b: Entry) -> bool:
		var ao: int = _order(a.id)
		var bo: int = _order(b.id)
		if ao != bo:
			return ao < bo
		if not is_equal_approx(a.difficulty, b.difficulty):
			return a.difficulty < b.difficulty
		return a.id < b.id)
	return result


static func _order(id: String) -> int:
	for song: Dictionary in ContentCatalog.songs():
		if song["id"] == id:
			return int(song.get("order", 100000))
	return 100000
