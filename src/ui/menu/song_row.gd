# One song in the song list: cover, title, difficulty badge, BPM · length and best result (the whole row selects the
# song), or for a locked song the unlock requirement with TRY (AD) / UNLOCK ALL.
# Related: src/ui/menu/song_list_panel.gd, src/ui/menu/song_detail_card.gd, tools/branding/build_brand.py (covers)
class_name SongRow
extends RefCounted

const COVER_DIRECTORY: String = "res://assets/covers"
const HEIGHT: float = 128.0
const COVER_SIZE: Vector2 = Vector2(150, 100)


## Playable song: a toggle RowButton (the panel puts them in one ButtonGroup) holding the layout; pressing it selects
## the song (the menu demo switches to it), the panel's SongDetailCard plays it. The selected row shows a PREVIEW tag.
static func playable(entry: SongCatalog.Entry) -> Button:
	var row: Button = UiTheme.make_button("", 0.0, HEIGHT, &"ui.tap")
	row.theme_type_variation = "RowButton"
	row.toggle_mode = true
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var layout: HBoxContainer = _layout(row)
	layout.add_child(cover(entry))
	var info: VBoxContainer = _info(entry)
	layout.add_child(info)
	var line: Label = best_line(HighScores.best(entry.path))
	if not line.text.is_empty():
		info.add_child(line)
	var tag: PanelContainer = _preview_tag()
	tag.modulate.a = 0.0
	layout.add_child(tag)
	row.toggled.connect(func(on: bool) -> void: tag.modulate.a = 1.0 if on else 0.0)
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
	return cover_art(entry.id)


## Cover of the song `id` (SongCatalog.song_id), for screens that only know the chart path (loading cover).
static func cover_art(id: String) -> Control:
	var path: String = ContentCatalog.cover_path(id)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = COVER_SIZE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = UiTheme.box(Color(0.08, 0.05, 0.2), Color(UiTheme.ACCENT, 0.5), 1, 0, 8)
	style.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", style)
	if ResourceLoader.exists(path) or path.begins_with("user://"):
		var art := TextureRect.new()
		art.texture = ContentPaths.cover(path)
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
	if bool(entry.remote.get("featured", false)):
		info.add_child(UiKit.label("FEATURED", "Caption"))
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
	if is_instance_valid(SongRatings.instance):
		var rating: String = SongRatings.instance.summary(entry.id)
		if not rating.is_empty():
			info.add_child(UiKit.label(rating, "Caption"))
	return info


## "BEST 12,340  ·  CLEARED" (empty text when the song was never played).
static func best_line(record: HighScores.Record) -> Label:
	var text: String = Locale.t("BEST %s  ·  %s") % [RunRecords.grouped(record.score), _result(record)] 			if record.has_any() else ""
	var line: Label = UiKit.label(text, "Muted")
	line.add_theme_font_size_override("font_size", 22)
	return line


static func _result(record: HighScores.Record) -> String:
	return Locale.t("CLEARED") if record.completed else "%d%%" % int(floorf(record.progress * 100.0))


## Marks the selected row: the song the menu demo is playing.
static func _preview_tag() -> PanelContainer:
	var tag := PanelContainer.new()
	tag.theme_type_variation = "Pill"
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(UiKit.icon_rect(&"music", 22, UiTheme.HOT))
	var text: Label = UiKit.label("PREVIEW")
	text.add_theme_font_size_override("font_size", 20)
	text.add_theme_color_override("font_color", UiTheme.HOT)
	content.add_child(text)
	tag.add_child(content)
	return tag
