# The selected song in the song list: cover, title, difficulty, BPM · length, best result and the big pulsing action
# button (PLAY / PRACTICE / …) that starts it. Selecting a row only previews the song in the menu demo; this button is
# the way into the level. Related: src/ui/menu/song_list_panel.gd, src/ui/menu/song_row.gd
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
	top.add_child(_info_slot)
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


func show_song(entry: SongCatalog.Entry) -> void:
	for child: Node in _cover_slot.get_children() + _info_slot.get_children():
		child.queue_free()
	_button.disabled = entry == null
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


func focus_button() -> void:
	_button.grab_focus()
