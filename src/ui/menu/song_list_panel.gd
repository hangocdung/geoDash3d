# Song picker: the SongCatalog songs (title, difficulty, BPM, length, best result), easiest first; emits the chosen
# chart. With `apply_locks` (PLAY, PRACTICE) locked songs (SongUnlocks, GD3-242) show what opens them, a TRY (AD)
# button (PLAY, main-chain songs: a rewarded ad opens the song until the player leaves the level) and UNLOCK ALL,
# which asks for the shop. Dev tools list every song. Related: src/core/song_unlocks.gd, src/ui/menu/main_menu.gd
class_name SongListPanel
extends PanelContainer

signal chosen(chart_path: String)
signal closed
signal shop_requested

const LIST_HEIGHT: float = 430.0
const ENTRY_WIDTH: float = 540.0

var heading: String = "PLAY"
## False for the dev tools (RECORD / AUTOPLAY): every song is playable.
var apply_locks: bool = true
## Only PLAY offers rewarded trials (practice needs the song open).
var allow_trials: bool = true

var _status: Label


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	column.add_child(UiTheme.make_label(heading, 48, UiTheme.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ENTRY_WIDTH + 20.0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var songs := VBoxContainer.new()
	songs.add_theme_constant_override("separation", 12)
	songs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(songs)
	var entries: Array[SongCatalog.Entry] = SongCatalog.list_songs()
	var titles: Dictionary[String, String] = {}
	var ordered: PackedStringArray = []
	for entry: SongCatalog.Entry in entries:
		titles[entry.path] = entry.title
		ordered.append(entry.path)
	var open: Dictionary[String, bool] = SongUnlocks.unlocked(ordered)
	var first: Button = null
	var any_locked: bool = false
	for entry: SongCatalog.Entry in entries:
		if not apply_locks or open.has(entry.path):
			var button: Button = _song_button(entry)
			songs.add_child(button)
			if first == null:
				first = button
		else:
			any_locked = true
			songs.add_child(_locked_entry(entry, titles.get(SongUnlocks.requirement(entry.path, ordered), "")))
	_status = UiTheme.make_label("", 24, UiTheme.HOT)
	column.add_child(_status)
	var back: Button = UiTheme.make_button("BACK", 360.0, 72.0, &"ui.back")
	back.pressed.connect(func() -> void: closed.emit())
	column.add_child(back)
	(first if first != null else back).grab_focus()
	if any_locked and allow_trials:
		Ads.preload_rewarded()


func _song_button(entry: SongCatalog.Entry) -> Button:
	var label: String = _details(entry)
	var record: HighScores.Record = HighScores.best(entry.path)
	if record.has_any():
		label += "\n" + Locale.t("BEST %s  ·  %s") % [RunRecords.grouped(record.score),
				Locale.t("CLEARED") if record.completed else "%d%%" % int(floorf(record.progress * 100.0))]
	var button: Button = UiTheme.make_button(label, ENTRY_WIDTH, 126.0 if record.has_any() else 92.0, &"ui.confirm")
	button.pressed.connect(func() -> void:
		Telemetry.log_event("song_select", {"song_id": entry.id})
		chosen.emit(entry.path))
	return button


## A locked song: its details and what opens it, then TRY (AD) / UNLOCK ALL.
func _locked_entry(entry: SongCatalog.Entry, requirement_title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var how: String = Locale.t("Clear %s to unlock") % requirement_title.to_upper() \
			if SongUnlocks.needs_clear(entry.path) else Locale.t("Clear %s or reach %d%% to unlock") % [
				requirement_title.to_upper(), roundi(RemoteSettings.get_float("unlock_progress") * 100.0)]
	var info: Button = UiTheme.make_button("%s\n%s · %s" % [_details(entry), Locale.t("LOCKED"), how],
			ENTRY_WIDTH, 126.0)
	info.disabled = true
	box.add_child(info)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	if allow_trials and RemoteSettings.get_bool("rewarded_trials") and not SongUnlocks.needs_clear(entry.path) \
			and (Ads.is_supported() or OS.is_debug_build()):
		var trial: Button = UiTheme.make_button("TRY (AD)", (ENTRY_WIDTH - 12.0) * 0.5, 60.0, &"ui.confirm")
		trial.pressed.connect(_start_trial.bind(entry))
		trial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(trial)
	var unlock_all: Button = UiTheme.make_button("UNLOCK ALL", (ENTRY_WIDTH - 12.0) * 0.5, 60.0)
	unlock_all.pressed.connect(func() -> void: shop_requested.emit())
	unlock_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(unlock_all)
	return box


## Rewarded trial: the ad, then the song (debug builds without ads, e.g. on PC, skip the ad).
func _start_trial(entry: SongCatalog.Entry) -> void:
	var play := func() -> void:
		SongUnlocks.trial_path = entry.path
		Telemetry.log_event("rewarded_trial", {"song_id": entry.id})
		chosen.emit(entry.path)
	if not Ads.is_supported():
		play.call()
	elif not Ads.show_rewarded("song_trial", play):
		Ads.preload_rewarded()
		_status.text = Locale.t("The ad is not ready yet, try again in a moment.")


func _details(entry: SongCatalog.Entry) -> String:
	var minutes: int = int(entry.length_sec) / 60
	return "%s\n%s  ·  %d BPM  ·  %d:%02d" % [entry.title.to_upper(), ChartDifficulty.tier_name(entry.difficulty),
			roundi(entry.bpm), minutes, int(entry.length_sec) % 60]
