# The selected song in the song list: cover, title, difficulty, BPM · length, best result, a spinner while the menu
# demo loads it, and the big pulsing action button (PLAY / PRACTICE / …) that starts it. Selecting a row only previews
# the song in the menu demo; this button is the way into the level (off for a locked song, which shows what opens it).
# Related: src/ui/menu/song_list_panel.gd, src/ui/menu/song_row.gd, src/ui/loading/loading_spinner.gd
class_name SongDetailCard
extends PanelContainer

signal action_pressed

const COVER_SIZE: Vector2 = Vector2(210, 140)
const BUTTON_HEIGHT: float = 112.0
const BUTTON_FONT_SIZE: int = 46
const PULSE_SEC: float = 0.9

var _cover_slot: Control
var _info_slot: VBoxContainer
var _button: Button
var _loading_row: HBoxContainer


## `text` / `icon`: the mode's action, e.g. "PLAY" / &"play".
func _init(text: String, icon: StringName) -> void:
	theme_type_variation = "Card"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	column.add_child(top)
	_cover_slot = Control.new()
	_cover_slot.custom_minimum_size = COVER_SIZE
	top.add_child(_cover_slot)
	_info_slot = VBoxContainer.new()
	_info_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	var info_column := VBoxContainer.new()
	info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_column.alignment = BoxContainer.ALIGNMENT_CENTER
	info_column.add_theme_constant_override("separation", 8)
	info_column.add_child(_info_slot)
	_loading_row = HBoxContainer.new()
	_loading_row.add_theme_constant_override("separation", 12)
	_loading_row.visible = false
	var spinner := LoadingSpinner.new(30.0)
	spinner.line_width = 4.0
	_loading_row.add_child(spinner)
	var loading: Label = UiKit.label("LOADING PREVIEW", "Caption")
	_loading_row.add_child(loading)
	info_column.add_child(_loading_row)
	top.add_child(info_column)
	_button = UiKit.button(text, icon, "PrimaryButton", false, Vector2(0, BUTTON_HEIGHT), &"ui.confirm")
	_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button.icon = UiIcons.get_icon(icon, 48, Color.WHITE)
	_button.add_theme_font_override("font", UiTheme.heading_font())
	_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	_button.pressed.connect(func() -> void: action_pressed.emit())
	column.add_child(_button)


func _ready() -> void:
	# A slow glow pulse draws the eye to the one button that starts the level.
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(_button, "self_modulate", Color(1.3, 1.15, 1.3), PULSE_SEC).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_button, "self_modulate", Color.WHITE, PULSE_SEC).set_trans(Tween.TRANS_SINE)


## `locked`: what opens the song (empty when it is open); a locked song can be listened to but not started.
func show_song(entry: SongCatalog.Entry, locked: String = "") -> void:
	for child: Node in _cover_slot.get_children() + _info_slot.get_children():
		child.queue_free()
	_button.disabled = entry == null or not locked.is_empty()
	if entry == null:
		return
	var art: Control = SongRow.cover(entry)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover_slot.add_child(art)
	var title: Label = UiKit.label(entry.title.to_upper())
	title.add_theme_font_override("font", UiTheme.heading_font())
	title.add_theme_font_size_override("font_size", 34)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_slot.add_child(title)
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 16)
	var tier: String = ChartDifficulty.tier_name(entry.difficulty)
	meta.add_child(UiKit.badge(tier, UiTheme.TIER_COLORS.get(tier, UiTheme.VIOLET)))
	var details: Label = UiKit.label("%d BPM  ·  %d:%02d" % [roundi(entry.bpm), int(entry.length_sec) / 60,
			int(entry.length_sec) % 60], "Muted")
	details.add_theme_font_size_override("font_size", 22)
	meta.add_child(details)
	_info_slot.add_child(meta)
	var best: Label = SongRow.best_line(HighScores.best(entry.path))
	if best.text.is_empty():
		best.text = Locale.t("NOT PLAYED YET")
	_info_slot.add_child(best)
	if not locked.is_empty():
		var how: Label = UiKit.label("%s · %s" % [Locale.t("LOCKED"), locked], "Muted")
		how.add_theme_font_size_override("font_size", 22)
		how.add_theme_color_override("font_color", UiTheme.HOT)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_slot.add_child(how)
	var rating := SongRatingWidget.new()
	rating.song_id = entry.id
	_info_slot.add_child(rating)
	var favorite: Button = UiKit.button("★ Favorite" if UserSettings.favorite_song_ids.has(entry.id) else "☆ Favorite",
			&"", "", false, Vector2(0, 48))
	favorite.pressed.connect(func() -> void:
		var ids: PackedStringArray = UserSettings.favorite_song_ids
		if ids.has(entry.id):
			ids.remove_at(ids.find(entry.id))
		else:
			ids.append(entry.id)
		UserSettings.favorite_song_ids = ids
		UserSettings.save_settings()
		favorite.text = "★ Favorite" if ids.has(entry.id) else "☆ Favorite")
	_info_slot.add_child(favorite)


func set_loading(loading: bool) -> void:
	_loading_row.visible = loading


func focus_button() -> void:
	_button.grab_focus()
