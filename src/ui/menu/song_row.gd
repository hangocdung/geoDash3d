# One song in the song list: cover, title, difficulty badge, BPM · length, best score and a PLAY tag (the whole row is
# the button), or for a locked song the unlock requirement with TRY (AD) / UNLOCK ALL. Portrait rows fold the best
# score under the title. Related: src/ui/menu/song_list_panel.gd, tools/branding/build_brand.py (covers)
class_name SongRow
extends RefCounted

const COVER_DIRECTORY: String = "res://assets/covers"
const HEIGHT: float = 128.0
const COVER_SIZE: Vector2 = Vector2(150, 100)
const BEST_WIDTH: float = 250.0


## Playable song: a RowButton holding the layout; `pressed` plays it.
static func playable(entry: SongCatalog.Entry, portrait: bool) -> Button:
	var row: Button = UiTheme.make_button("", 0.0, HEIGHT, &"ui.confirm")
	row.theme_type_variation = "RowButton"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var layout: HBoxContainer = _layout(row)
	layout.add_child(cover(entry))
	var info: VBoxContainer = _info(entry)
	layout.add_child(info)
	var record: HighScores.Record = HighScores.best(entry.path)
	if portrait:
		if record.has_any():
			var line: Label = UiKit.label(Locale.t("BEST %s  ·  %s") % [RunRecords.grouped(record.score), _result(record)],
					"Muted")
			line.add_theme_font_size_override("font_size", 22)
			info.add_child(line)
	else:
		layout.add_child(_best(record))
	var tag: PanelContainer = _play_tag()
	layout.add_child(tag)
	var highlight := func(on: bool) -> void:
		tag.add_theme_stylebox_override("panel", _tag_style(on))
	row.mouse_entered.connect(highlight.bind(true))
	row.mouse_exited.connect(func() -> void: highlight.call(row.has_focus()))
	row.focus_entered.connect(highlight.bind(true))
	row.focus_exited.connect(highlight.bind(false))
	return row


## Locked song: dimmed cover with a lock, what opens it, and the actions (`actions` holds TRY / UNLOCK ALL buttons).
static func locked(entry: SongCatalog.Entry, requirement: String, actions: Array[Button], portrait: bool) -> PanelContainer:
	var row := PanelContainer.new()
	row.theme_type_variation = "Row"
	row.custom_minimum_size = Vector2(0, HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 22)
	row.add_child(layout)
	var art: Control = cover(entry)
	art.modulate = Color(0.45, 0.45, 0.6)
	var lock: TextureRect = UiKit.icon_rect(&"lock", 44, Color.WHITE)
	lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	art.add_child(lock)
	layout.add_child(art)
	var info: VBoxContainer = _info(entry)
	var how: Label = UiKit.label("%s · %s" % [Locale.t("LOCKED"), requirement], "Muted")
	how.add_theme_font_size_override("font_size", 22)
	how.add_theme_color_override("font_color", UiTheme.HOT)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(how)
	layout.add_child(info)
	var buttons := BoxContainer.new()
	buttons.vertical = not portrait or actions.size() > 1
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	for button: Button in actions:
		button.custom_minimum_size = Vector2(200 if portrait else 230, 52)
		buttons.add_child(button)
	layout.add_child(buttons)
	return row


## The song's cover (assets/covers/<id>.jpg, shared by the LED variant), or a music icon on a dark tile.
static func cover(entry: SongCatalog.Entry) -> Control:
	var path: String = COVER_DIRECTORY.path_join(entry.id.trim_suffix("_led") + ".jpg")
	var frame := PanelContainer.new()
	frame.custom_minimum_size = COVER_SIZE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = UiTheme.box(Color(0.08, 0.05, 0.2), Color(UiTheme.ACCENT, 0.5), 1, 0, 8)
	style.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", style)
	if ResourceLoader.exists(path):
		var art := TextureRect.new()
		art.texture = load(path) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(art)
	else:
		frame.add_child(UiKit.icon_rect(&"music", 48, Color(UiTheme.VIOLET, 0.8)))
	return frame


static func _layout(row: Button) -> HBoxContainer:
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		layout.set_offset(side, 14.0 if side == SIDE_LEFT or side == SIDE_TOP else -14.0)
	layout.add_theme_constant_override("separation", 22)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(layout)
	return layout


static func _info(entry: SongCatalog.Entry) -> VBoxContainer:
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: Label = UiKit.label(entry.title.to_upper())
	title.add_theme_font_override("font", UiTheme.heading_font())
	title.add_theme_font_size_override("font_size", 28)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	info.add_child(title)
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 16)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tier: String = ChartDifficulty.tier_name(entry.difficulty)
	meta.add_child(UiKit.badge(tier, UiTheme.TIER_COLORS.get(tier, UiTheme.VIOLET)))
	var minutes: int = int(entry.length_sec) / 60
	var details: Label = UiKit.label("%d BPM  ·  %d:%02d" % [roundi(entry.bpm), minutes, int(entry.length_sec) % 60], "Muted")
	details.add_theme_font_size_override("font_size", 22)
	meta.add_child(details)
	info.add_child(meta)
	return info


static func _best(record: HighScores.Record) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(BEST_WIDTH, 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(UiKit.label("BEST SCORE", "Caption"))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(UiKit.label(RunRecords.grouped(record.score) if record.has_any() else "—", "BigNumber"))
	if record.has_any():
		var result: Label = UiKit.label(_result(record), "")
		result.add_theme_font_size_override("font_size", 24)
		result.add_theme_color_override("font_color", UiTheme.SUCCESS if record.completed else UiTheme.TEXT)
		line.add_child(result)
	column.add_child(line)
	return column


static func _result(record: HighScores.Record) -> String:
	return Locale.t("CLEARED") if record.completed else "%d%%" % int(floorf(record.progress * 100.0))


static func _play_tag() -> PanelContainer:
	var tag := PanelContainer.new()
	tag.custom_minimum_size = Vector2(170, 60)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("panel", _tag_style(false))
	var content := HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(UiKit.icon_rect(&"play", 26, Color.WHITE))
	var text: Label = UiKit.label("PLAY")
	text.add_theme_font_override("font", UiTheme.heading_font())
	text.add_theme_font_size_override("font_size", 26)
	content.add_child(text)
	tag.add_child(content)
	return tag


static func _tag_style(highlighted: bool) -> StyleBoxFlat:
	return UiTheme.box(UiTheme.PRIMARY, Color(1.0, 0.6, 0.95), 2, 14) if highlighted \
			else UiTheme.box(Color(0.03, 0.03, 0.1, 0.8), Color(UiTheme.ACCENT, 0.7), 2, 4)
