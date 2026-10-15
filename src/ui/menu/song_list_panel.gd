# Song picker: the SongCatalog songs easiest first as SongRow rows, filtered by difficulty (side tabs in landscape, a
# tab row in portrait); emits the chosen chart. With `apply_locks` (PLAY, PRACTICE) locked songs (SongUnlocks,
# GD3-242) show what opens them, a TRY (AD) button (PLAY, main-chain songs: a rewarded ad opens the song until the
# player leaves the level) and UNLOCK ALL, which asks for the shop. Dev tools list every song.
# Related: src/ui/menu/song_row.gd, src/core/song_unlocks.gd, src/ui/menu/main_menu.gd
class_name SongListPanel
extends UiScreen

signal chosen(chart_path: String)
signal shop_requested

const HEADING_ICONS: Dictionary[String, StringName] = {"PLAY": &"play", "PRACTICE": &"target", "RECORD": &"record",
		"AUTOPLAY": &"play"}
const ALL: String = "ALL SONGS"

var heading: String = "PLAY"
## False for the dev tools (RECORD / AUTOPLAY): every song is playable.
var apply_locks: bool = true
## Only PLAY offers rewarded trials (practice needs the song open).
var allow_trials: bool = true

var _status: Label
var _split: BoxContainer
var _filters: BoxContainer
var _filter_buttons: Array[Button] = []
var _songs: VBoxContainer
var _filter: String = ALL
var _entries: Array[SongCatalog.Entry] = []
var _titles: Dictionary[String, String] = {}
var _ordered: PackedStringArray = []
var _open: Dictionary[String, bool] = {}


func _title() -> String:
	return heading


func _subtitle() -> String:
	return "CHOOSE A TRACK AND FEEL THE RHYTHM"


func _icon() -> StringName:
	return HEADING_ICONS.get(heading, &"play")


func _build_body() -> void:
	_entries = SongCatalog.list_songs()
	for entry: SongCatalog.Entry in _entries:
		_titles[entry.path] = entry.title
		_ordered.append(entry.path)
	_open = SongUnlocks.unlocked(_ordered)
	_split = BoxContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_theme_constant_override("separation", 28)
	body.add_child(_split)
	_filters = BoxContainer.new()
	_filters.add_theme_constant_override("separation", 12)
	_split.add_child(_filters)
	var group := ButtonGroup.new()
	var tiers: PackedStringArray = [ALL]
	for entry: SongCatalog.Entry in _entries:
		var tier: String = ChartDifficulty.tier_name(entry.difficulty)
		if not tiers.has(tier):
			tiers.append(tier)
	for tier: String in tiers:
		var button: Button = UiKit.button(tier, &"music" if tier == ALL else &"star", "TabButton", false, Vector2(280, 68))
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = tier == _filter
		button.pressed.connect(func() -> void:
			_filter = tier
			_fill(UiKit.is_portrait(self)))
		_filters.add_child(button)
		_filter_buttons.append(button)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_child(scroll)
	_songs = VBoxContainer.new()
	_songs.add_theme_constant_override("separation", 14)
	_songs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_songs)
	_status = UiKit.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_color_override("font_color", UiTheme.HOT)
	body.add_child(_status)


func _layout(is_portrait: bool) -> void:
	_split.vertical = is_portrait
	_filters.vertical = not is_portrait
	for button: Button in _filter_buttons:
		button.custom_minimum_size = Vector2(0, 64) if is_portrait else Vector2(280, 68)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_portrait else Control.SIZE_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER if is_portrait else HORIZONTAL_ALIGNMENT_LEFT
		button.icon = null if is_portrait else UiIcons.get_icon(&"music" if button.text == ALL else &"star", 26,
				UiTheme.ACCENT)
	_fill(is_portrait)


## Rebuilds the rows for the current filter and orientation.
func _fill(portrait: bool) -> void:
	for child: Node in _songs.get_children():
		child.queue_free()
	var first: Button = null
	var any_locked: bool = false
	for entry: SongCatalog.Entry in _entries:
		if _filter != ALL and ChartDifficulty.tier_name(entry.difficulty) != _filter:
			continue
		if not apply_locks or _open.has(entry.path):
			var row: Button = SongRow.playable(entry, portrait)
			row.pressed.connect(func() -> void:
				Telemetry.log_event("song_select", {"song_id": entry.id})
				chosen.emit(entry.path))
			_songs.add_child(row)
			if first == null:
				first = row
		else:
			any_locked = true
			_songs.add_child(SongRow.locked(entry, _requirement(entry), _locked_actions(entry), portrait))
	if first != null:
		first.grab_focus()
	if any_locked and allow_trials:
		Ads.preload_rewarded()


func _requirement(entry: SongCatalog.Entry) -> String:
	var title: String = _titles.get(SongUnlocks.requirement(entry.path, _ordered), "").to_upper()
	if SongUnlocks.needs_clear(entry.path):
		return Locale.t("Clear %s to unlock") % title
	return Locale.t("Clear %s or reach %d%% to unlock") % [title,
			roundi(RemoteSettings.get_float("unlock_progress") * 100.0)]


func _locked_actions(entry: SongCatalog.Entry) -> Array[Button]:
	var actions: Array[Button] = []
	if allow_trials and RemoteSettings.get_bool("rewarded_trials") and not SongUnlocks.needs_clear(entry.path) \
			and (Ads.is_supported() or OS.is_debug_build()):
		var trial: Button = UiKit.button("TRY (AD)", &"ad", "PrimaryButton", false, Vector2(230, 52), &"ui.confirm")
		trial.add_theme_font_size_override("font_size", 22)
		trial.pressed.connect(_start_trial.bind(entry))
		actions.append(trial)
	var unlock_all: Button = UiKit.button("UNLOCK ALL", &"unlock", "", false, Vector2(230, 52))
	unlock_all.add_theme_font_size_override("font_size", 22)
	unlock_all.pressed.connect(func() -> void: shop_requested.emit())
	actions.append(unlock_all)
	return actions


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
