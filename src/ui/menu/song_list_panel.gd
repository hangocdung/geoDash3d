# Song picker: every *.chart.json in assets/music (title, difficulty, BPM, length, best result), easiest first;
# emits the chosen chart. Charts named *.classic.chart.json are kept for comparisons and not listed.
# Related: src/ui/menu/main_menu.gd, src/gameplay/chart/chart_difficulty.gd
class_name SongListPanel
extends PanelContainer

signal chosen(chart_path: String)
signal closed

const MUSIC_DIRECTORY: String = "res://assets/music"
const LIST_HEIGHT: float = 430.0


class Entry:
	var path: String
	var title: String
	var bpm: float
	var length_sec: float
	var difficulty: float


var heading: String = "PLAY"


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	column.add_child(UiTheme.make_label(heading, 48, UiTheme.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var songs := VBoxContainer.new()
	songs.add_theme_constant_override("separation", 12)
	songs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(songs)
	var first: Button = null
	for entry: Entry in list_songs():
		var minutes: int = int(entry.length_sec) / 60
		var label: String = "%s\n%s  ·  %d BPM  ·  %d:%02d" % [entry.title.to_upper(),
				ChartDifficulty.tier_name(entry.difficulty), roundi(entry.bpm), minutes, int(entry.length_sec) % 60]
		var record: HighScores.Record = HighScores.best(entry.path)
		if record.has_any():
			label += "\nBEST %s  ·  %s" % [RunRecords.grouped(record.score),
					"CLEARED" if record.completed else "%d%%" % int(floorf(record.progress * 100.0))]
		var button: Button = UiTheme.make_button(label, 540.0, 126.0 if record.has_any() else 92.0, &"ui.confirm")
		button.pressed.connect(func() -> void: chosen.emit(entry.path))
		songs.add_child(button)
		if first == null:
			first = button
	var back: Button = UiTheme.make_button("BACK", 360.0, 72.0, &"ui.back")
	back.pressed.connect(func() -> void: closed.emit())
	column.add_child(back)
	(first if first != null else back).grab_focus()


## Reads each chart's JSON (cheap; the level does the full validation), easiest first (ChartDifficulty).
static func list_songs() -> Array[Entry]:
	var entries: Array[Entry] = []
	for file_name: String in DirAccess.get_files_at(MUSIC_DIRECTORY):
		if not file_name.ends_with(".chart.json") or file_name.ends_with(".classic.chart.json"):
			continue
		var path: String = MUSIC_DIRECTORY.path_join(file_name)
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(data) != TYPE_DICTIONARY:
			push_error("SongListPanel: cannot read chart '%s'" % path)
			continue
		var chart: Dictionary = data
		var tempo: Array = chart.get("tempo", [])
		var entry := Entry.new()
		entry.path = path
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
