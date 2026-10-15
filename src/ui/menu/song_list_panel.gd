# Song picker: the SongCatalog songs easiest first as SongRow rows under difficulty tabs. Pressing a row only selects it:
# `previewed` lets the menu demo play that song behind the page (list side dark, demo side clear in landscape), and the
# SongDetailCard's big button emits `chosen`. With `apply_locks` (PLAY, PRACTICE) locked songs (SongUnlocks, GD3-242)
# show what opens them, a TRY (AD) button (PLAY, main-chain songs: a rewarded ad opens the song until the player
# leaves the level) and UNLOCK ALL, which asks for the shop. Dev tools list every song.
# Related: src/ui/menu/song_row.gd, src/ui/menu/song_detail_card.gd, src/core/song_unlocks.gd, src/ui/menu/main_menu.gd
class_name SongListPanel
extends UiScreen

signal chosen(chart_path: String)
## The selection changed: the menu demo should play this chart.
signal previewed(chart_path: String)
signal shop_requested

const HEADING_ICONS: Dictionary[String, StringName] = {"PLAY": &"play", "PRACTICE": &"target", "RECORD": &"record",
		"AUTOPLAY": &"play"}
const ALL: String = "ALL SONGS"
## Landscape: the list column's share of the width; the demo shows on the rest, the card at its bottom.
const LIST_SHARE: float = 0.54
const BACKDROP_COLOR: Color = Color(0.02, 0.0, 0.07)

var heading: String = "PLAY"
## False for the dev tools (RECORD / AUTOPLAY): every song is playable.
var apply_locks: bool = true
## Only PLAY offers rewarded trials (practice needs the song open).
var allow_trials: bool = true
## Chart selected when the page opens (the song the demo is playing); falls back to the first open song.
var selected_path: String = ""

var _status: Label
var _split: BoxContainer
var _list_column: VBoxContainer
var _card: SongDetailCard
var _backdrop: TextureRect
var _songs: VBoxContainer
var _rows: ButtonGroup
var _filter: String = ALL
var _entries: Array[SongCatalog.Entry] = []
var _titles: Dictionary[String, String] = {}
var _ordered: PackedStringArray = []
var _open: Dictionary[String, bool] = {}


func _title() -> String:
	return heading


func _subtitle() -> String:
	return "PICK A SONG, THEN PRESS PLAY" if heading == "PLAY" else "CHOOSE A TRACK AND FEEL THE RHYTHM"


func _icon() -> StringName:
	return HEADING_ICONS.get(heading, &"play")


func _build_body() -> void:
	_entries = SongCatalog.list_songs()
	for entry: SongCatalog.Entry in _entries:
		_titles[entry.path] = entry.title
		_ordered.append(entry.path)
	_open = SongUnlocks.unlocked(_ordered)
	_build_backdrop()
	_split = BoxContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_theme_constant_override("separation", 28)
	body.add_child(_split)
	_list_column = VBoxContainer.new()
	_list_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_column.size_flags_stretch_ratio = LIST_SHARE / (1.0 - LIST_SHARE)
	_list_column.add_theme_constant_override("separation", 16)
	_split.add_child(_list_column)
	_list_column.add_child(_build_filters())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_column.add_child(scroll)
	_songs = VBoxContainer.new()
	_songs.add_theme_constant_override("separation", 14)
	_songs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_songs)
	_rows = ButtonGroup.new()
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_END
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(side)
	_card = SongDetailCard.new(heading, HEADING_ICONS.get(heading, &"play"))
	_card.action_pressed.connect(_on_action)
	side.add_child(_card)
	_status = UiKit.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_color_override("font_color", UiTheme.HOT)
	body.add_child(_status)
	if not _is_playable(selected_path):
		selected_path = ""
		for entry: SongCatalog.Entry in _entries:
			if _is_playable(entry.path):
				selected_path = entry.path
				break
	_card.show_song(_entry(selected_path))
	if not selected_path.is_empty():
		previewed.emit(selected_path)


## Difficulty tabs, one row above the list.
func _build_filters() -> HBoxContainer:
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	var tiers: PackedStringArray = [ALL]
	for entry: SongCatalog.Entry in _entries:
		var tier: String = ChartDifficulty.tier_name(entry.difficulty)
		if not tiers.has(tier):
			tiers.append(tier)
	for tier: String in tiers:
		var button: Button = UiKit.button(tier, &"", "TabButton", false, Vector2(0, 58))
		button.add_theme_font_size_override("font_size", 22)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = tier == _filter
		button.pressed.connect(func() -> void:
			_filter = tier
			_fill(UiKit.is_portrait(self)))
		filters.add_child(button)
	return filters


## Landscape: dark behind the list, clear over the demo (like the home page). Portrait: the even shade.
func _build_backdrop() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BACKDROP_COLOR, 0.9))
	gradient.set_color(1, Color(BACKDROP_COLOR, 0.0))
	gradient.add_point(LIST_SHARE, Color(BACKDROP_COLOR, 0.75))
	gradient.add_point(LIST_SHARE + 0.12, Color(BACKDROP_COLOR, 0.1))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	_backdrop = TextureRect.new()
	_backdrop.texture = texture
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	move_child(_backdrop, shade.get_index() + 1)


func _layout(is_portrait: bool) -> void:
	_split.vertical = is_portrait
	shade.visible = is_portrait
	shade.color = Color(BACKDROP_COLOR, 0.55)
	_backdrop.visible = not is_portrait
	_fill(is_portrait)


## Rebuilds the rows for the current filter and orientation.
func _fill(portrait: bool) -> void:
	for child: Node in _songs.get_children():
		child.queue_free()
	var focus: Button = null
	var any_locked: bool = false
	for entry: SongCatalog.Entry in _entries:
		if _filter != ALL and ChartDifficulty.tier_name(entry.difficulty) != _filter:
			continue
		if _is_playable(entry.path):
			var row: Button = SongRow.playable(entry)
			row.button_group = _rows
			row.button_pressed = entry.path == selected_path
			row.pressed.connect(_select.bind(entry.path))
			_songs.add_child(row)
			if focus == null or row.button_pressed:
				focus = row
		else:
			any_locked = true
			_songs.add_child(SongRow.locked(entry, _requirement(entry), _locked_actions(entry), portrait))
	if focus != null:
		focus.grab_focus()
	if any_locked and allow_trials:
		Ads.preload_rewarded()


func _is_playable(path: String) -> bool:
	return _titles.has(path) and (not apply_locks or _open.has(path))


func _entry(path: String) -> SongCatalog.Entry:
	for entry: SongCatalog.Entry in _entries:
		if entry.path == path:
			return entry
	return null


## A row was pressed: show it on the card and let the demo play it (the level starts only from the card's button).
func _select(path: String) -> void:
	if path == selected_path:
		return
	selected_path = path
	_card.show_song(_entry(path))
	previewed.emit(path)


func _on_action() -> void:
	if selected_path.is_empty():
		return
	Telemetry.log_event("song_select", {"song_id": SongCatalog.song_id(selected_path)})
	chosen.emit(selected_path)


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
